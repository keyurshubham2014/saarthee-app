import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/api/app_error.dart';
import '../../../core/capture/blur/face_plate_detector.dart';
import '../../../core/capture/evidence_capture.dart';
import '../../../core/config/timings.dart';
import '../data/report_api.dart';
import 'report_draft_controller.dart';

/// Capture → blur on the device → upload, per photo (TASK-05 §6 steps 12–14).
/// The server only ever receives the blurred file (REQ-S-007).
class ReportPhotoPipeline {
  ReportPhotoPipeline(this._ref);

  final Ref _ref;

  ReportDraftController get _draft => _ref.read(reportDraftProvider.notifier);

  /// Moves a captured file into the draft folder and starts blur + upload.
  /// Returns the draft photo path.
  Future<String> addCaptured(CapturedPhoto captured) async {
    final dir = await _ref.read(reportPhotoDirProvider.future);
    final id = const Uuid().v4();
    final original = '${dir.path}/$id-orig.jpg';
    await File(captured.path).copy(original);
    final target = '${dir.path}/$id.jpg';
    _draft.addPhoto(
      DraftPhoto(
        localPath: target,
        capturedAt: captured.capturedAt,
        uploadState: UploadState.blurring,
      ),
    );
    final boxes = await detectBoxes(original);
    await renderBlurredFile(original, target, boxes ?? const [], pad: false);
    await _deleteQuietly(original);
    _draft.updatePhoto(
      target,
      (p) =>
          p.copy(blurApplied: boxes != null, uploadState: UploadState.pending),
    );
    await upload(target);
    return target;
  }

  /// Uprights the photo, then runs the automatic detector with a timeout.
  /// Null (manual tool only, with its note) when detection is unavailable,
  /// fails or times out (REQ-S-007).
  Future<List<BlurBox>?> detectBoxes(String path) async {
    final detector = _ref.read(faceAndPlateDetectorProvider);
    if (detector is UnavailableDetector) return null;
    try {
      await normaliseOrientation(path);
      return await detector.detect(path).timeout(AppTimings.blurDetectTimeout);
    } on Object {
      return null;
    }
  }

  /// Applies the manual blur tool's boxes to a draft photo and re-uploads it.
  Future<void> applyManualBlur(String localPath, List<BlurBox> boxes) async {
    if (boxes.isEmpty) return;
    final dir = await _ref.read(reportPhotoDirProvider.future);
    final tmp = '${dir.path}/${const Uuid().v4()}-manual.jpg';
    _draft.updatePhoto(
      localPath,
      (p) => p.copy(uploadState: UploadState.blurring),
    );
    await renderBlurredFile(localPath, tmp, boxes);
    await File(tmp).copy(localPath);
    await _deleteQuietly(tmp);
    _draft.updatePhoto(
      localPath,
      (p) => DraftPhoto(
        localPath: p.localPath,
        capturedAt: p.capturedAt,
        blurApplied: true,
      ),
    );
    await upload(localPath);
  }

  /// Uploads one draft photo (also "Retry upload" and resume on reconnect).
  Future<void> upload(String localPath) async {
    _draft.updatePhoto(
      localPath,
      (p) => p.copy(uploadState: UploadState.uploading, progress: 0),
    );
    final photo = _ref
        .read(reportDraftProvider)
        ?.photos
        .where((p) => p.localPath == localPath)
        .firstOrNull;
    if (photo == null) return;
    try {
      final id = await _ref
          .read(reportApiProvider)
          .uploadPhoto(
            localPath,
            blurApplied: photo.blurApplied,
            onProgress: (v) =>
                _draft.updatePhoto(localPath, (p) => p.copy(progress: v)),
          );
      _draft.updatePhoto(
        localPath,
        (p) => p.copy(photoId: id, uploadState: UploadState.uploaded),
      );
    } on AppError {
      _draft.updatePhoto(
        localPath,
        (p) => p.copy(uploadState: UploadState.failed),
      );
    }
  }

  /// Uploads every photo that is not uploaded yet (relaunch, reconnect).
  Future<void> resumePending() async {
    final photos = _ref.read(reportDraftProvider)?.photos ?? const [];
    for (final p in photos) {
      if (p.uploadState != UploadState.uploaded &&
          p.uploadState != UploadState.uploading &&
          File(p.localPath).existsSync()) {
        await upload(p.localPath);
      }
    }
  }

  static Future<void> _deleteQuietly(String path) async {
    try {
      await File(path).delete();
    } on FileSystemException {
      // Already gone.
    }
  }
}

final reportPhotoPipelineProvider = Provider<ReportPhotoPipeline>(
  ReportPhotoPipeline.new,
);
