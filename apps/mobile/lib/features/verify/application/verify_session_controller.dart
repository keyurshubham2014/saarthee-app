import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/app_error.dart';
import '../../../core/capture/evidence_capture.dart';
import '../../../core/config/app_config.dart';
import '../data/verify_repository.dart';
import 'verify_token.dart';

enum VerifyAnswer { fixed, notFixed }

enum VerifyLoad { idle, loading, ready, failed }

enum VerifyUpload { idle, uploading, failed, done }

/// Verify routes (02 §3.1).
class VerifyRoutes {
  const VerifyRoutes._();

  static const entry = '/verify';
  static const enterCode = '/verify/enter-code';
  static const answer = '/verify/answer';
  static const photo = '/verify/photo';
  static const note = '/verify/note';
  static const check = '/verify/check';
  static const done = '/verify/done';
}

/// In-memory verify session (02 §5.1): summary, answer, photo, note.
/// Nothing here is persisted; it is discarded on completion or app close.
class VerifySession {
  const VerifySession({
    this.load = VerifyLoad.idle,
    this.loadError,
    this.summary,
    this.reportPhoto,
    this.answer,
    this.photoPath,
    this.fix,
    this.capturedAt,
    this.photoId,
    this.upload = VerifyUpload.idle,
    this.uploadProgress = 0,
    this.uploadError,
    this.note = '',
    this.sending = false,
    this.submitError,
    this.clientSubmissionId,
  });

  final VerifyLoad load;
  final AppError? loadError;
  final VerifySummary? summary;
  final Uint8List? reportPhoto;
  final VerifyAnswer? answer;
  final String? photoPath;
  final Fix? fix;
  final DateTime? capturedAt;
  final String? photoId;
  final VerifyUpload upload;
  final double uploadProgress;
  final AppError? uploadError;
  final String note;
  final bool sending;
  final AppError? submitError;
  final String? clientSubmissionId;

  /// Steps: answer, photo, (note when not fixed), check.
  int get totalSteps => answer == VerifyAnswer.notFixed ? 4 : 3;

  VerifySession copyWith({
    VerifyLoad? load,
    AppError? loadError,
    VerifySummary? summary,
    Uint8List? reportPhoto,
    VerifyAnswer? answer,
    String? photoPath,
    Fix? fix,
    DateTime? capturedAt,
    String? photoId,
    VerifyUpload? upload,
    double? uploadProgress,
    AppError? uploadError,
    String? note,
    bool? sending,
    AppError? submitError,
    String? clientSubmissionId,
    bool clearLoadError = false,
    bool clearUploadError = false,
    bool clearSubmitError = false,
    bool clearPhoto = false,
  }) => VerifySession(
    load: load ?? this.load,
    loadError: clearLoadError ? null : (loadError ?? this.loadError),
    summary: summary ?? this.summary,
    reportPhoto: reportPhoto ?? this.reportPhoto,
    answer: answer ?? this.answer,
    photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
    fix: clearPhoto ? null : (fix ?? this.fix),
    capturedAt: clearPhoto ? null : (capturedAt ?? this.capturedAt),
    photoId: clearPhoto ? null : (photoId ?? this.photoId),
    upload: upload ?? this.upload,
    uploadProgress: uploadProgress ?? this.uploadProgress,
    uploadError: clearUploadError ? null : (uploadError ?? this.uploadError),
    note: note ?? this.note,
    sending: sending ?? this.sending,
    submitError: clearSubmitError ? null : (submitError ?? this.submitError),
    clientSubmissionId: clientSubmissionId ?? this.clientSubmissionId,
  );
}

class VerifySessionController extends Notifier<VerifySession> {
  VerifyRepository get _repo => ref.read(verifyRepositoryProvider);

  String? get _token => ref.read(verifyTokenProvider);

  @override
  VerifySession build() => const VerifySession();

  /// Opens the session for [token] (from the deep link or manual entry):
  /// loads the summary and the original photo.
  Future<void> openWithToken(String token) async {
    ref.read(verifyTokenProvider.notifier).set(token);
    await _deletePhotoFile();
    state = VerifySession(
      load: VerifyLoad.loading,
      clientSubmissionId: const Uuid().v4(),
    );
    await reload();
  }

  Future<void> reload() async {
    final token = _token;
    if (token == null) {
      state = state.copyWith(
        load: VerifyLoad.failed,
        loadError: const AppError(code: 'VERIFY_TOKEN_INVALID'),
      );
      return;
    }
    state = state.copyWith(load: VerifyLoad.loading, clearLoadError: true);
    try {
      final summary = await _repo.complaint(token);
      Uint8List? photo;
      if (summary.hasPhoto) {
        try {
          photo = await _repo.reportPhoto(token);
        } on AppError catch (e) {
          if (e.code != 'NOT_FOUND') rethrow;
        }
      }
      state = state.copyWith(
        load: VerifyLoad.ready,
        summary: summary,
        reportPhoto: photo,
      );
    } on AppError catch (e) {
      state = state.copyWith(load: VerifyLoad.failed, loadError: e);
    }
  }

  void setAnswer(VerifyAnswer a) => state = state.copyWith(answer: a);

  Future<void> setPhoto(CapturedPhoto photo, Fix fix) async {
    await _deletePhotoFile();
    state = state.copyWith(
      clearPhoto: true,
      upload: VerifyUpload.idle,
      uploadProgress: 0,
      clearUploadError: true,
    );
    state = state.copyWith(
      photoPath: photo.path,
      fix: fix,
      capturedAt: photo.capturedAt,
    );
    await uploadPhoto();
  }

  Future<void> uploadPhoto() async {
    final token = _token;
    final path = state.photoPath;
    if (token == null || path == null) return;
    if (state.upload == VerifyUpload.uploading) return;
    state = state.copyWith(
      upload: VerifyUpload.uploading,
      uploadProgress: 0,
      clearUploadError: true,
    );
    try {
      final id = await _repo.uploadPhoto(
        token,
        path,
        onProgress: (p) => state = state.copyWith(uploadProgress: p),
      );
      state = state.copyWith(
        photoId: id,
        upload: VerifyUpload.done,
        uploadProgress: 1,
      );
    } on AppError catch (e) {
      state = state.copyWith(upload: VerifyUpload.failed, uploadError: e);
    }
  }

  void setNote(String note) => state = state.copyWith(note: note);

  /// POST /verify/submissions, same `clientSubmissionId` on retries.
  Future<bool> submit() async {
    final token = _token;
    final s = state;
    if (token == null || s.sending) return false;
    state = s.copyWith(sending: true, clearSubmitError: true);
    final note = s.answer == VerifyAnswer.notFixed ? s.note.trim() : '';
    try {
      await _repo.submit(token, {
        'clientSubmissionId': s.clientSubmissionId,
        'result': s.answer == VerifyAnswer.fixed ? 'fixed' : 'not_fixed',
        'photoId': s.photoId,
        'latitude': _round6(s.fix?.latitude),
        'longitude': _round6(s.fix?.longitude),
        if (s.fix != null) 'gpsAccuracyM': s.fix!.accuracy,
        'deviceCapturedAt': s.capturedAt?.toUtc().toIso8601String(),
        if (note.isNotEmpty) 'note': note,
        'platform': appPlatformName(),
        'appVersion': AppConfig.appVersion,
      });
      state = state.copyWith(sending: false);
      return true;
    } on AppError catch (e) {
      if (e.code == 'PHOTO_UNUSABLE') {
        await _deletePhotoFile();
        state = state.copyWith(
          clearPhoto: true,
          upload: VerifyUpload.idle,
          uploadProgress: 0,
        );
      }
      state = state.copyWith(sending: false, submitError: e);
      return false;
    }
  }

  /// Ends the session: forgets the token and all answers.
  Future<void> finish() async {
    await _deletePhotoFile();
    ref.read(verifyTokenProvider.notifier).clear();
    state = const VerifySession();
  }

  Future<void> _deletePhotoFile() async {
    final path = state.photoPath;
    if (path == null) return;
    final f = File(path);
    if (f.existsSync()) await f.delete();
  }

  static double? _round6(double? v) =>
      v == null ? null : double.parse(v.toStringAsFixed(6));
}

final verifySessionProvider =
    NotifierProvider<VerifySessionController, VerifySession>(
      VerifySessionController.new,
    );
