import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

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
    var applied = boxes != null;
    final render = Stopwatch()..start();
    try {
      await renderBlurredFile(original, target, boxes ?? const [], pad: false);
    } on Object {
      // A render error must not drop the photo or mark it blurred: keep the
      // original and offer the manual tool with its note.
      await File(original).copy(target);
      applied = false;
    }
    _logTiming('render', render, applied ? 'ok' : 'failed');
    await _deleteQuietly(original);
    _draft.updatePhoto(
      target,
      (p) => p.copy(
        blurApplied: applied,
        uploadState: UploadState.pending,
        revision: p.revision + 1,
      ),
    );
    await upload(target);
    return target;
  }

  /// Uprights the photo, then runs the automatic detector. [timeout] covers
  /// detection only; orientation and rendering are timed separately (logged
  /// as non-personal timings, no paths). Null (manual tool only, with its
  /// note) when detection is unavailable, fails or times out (REQ-S-007).
  /// An empty list means the pass ran and found nothing (still "blurred").
  Future<List<BlurBox>?> detectBoxes(
    String path, {
    Duration timeout = AppTimings.blurDetectTimeout,
  }) async {
    final detector = _ref.read(faceAndPlateDetectorProvider);
    if (detector is UnavailableDetector) {
      _logTiming('detect', Stopwatch(), 'unavailable');
      return null;
    }
    final orient = Stopwatch()..start();
    try {
      await normaliseOrientation(path);
      _logTiming('orient', orient, 'ok');
    } on Object {
      _logTiming('orient', orient, 'failed');
      return null;
    }
    final detect = Stopwatch()..start();
    try {
      final boxes = await detector.detect(path).timeout(timeout);
      _logTiming(
        'detect',
        detect,
        boxes == null ? 'none' : '${boxes.length} boxes',
      );
      return boxes;
    } on TimeoutException {
      _logTiming('detect', detect, 'timeout');
      return null;
    } on Object {
      _logTiming('detect', detect, 'error');
      return null;
    }
  }

  /// Phase timings for the blur pass. Only the phase, milliseconds and a
  /// result word are printed: no file paths, boxes or image content.
  static void _logTiming(String phase, Stopwatch sw, String result) =>
      debugPrint('saarthee.blur $phase ${sw.elapsedMilliseconds}ms $result');

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
        revision: p.revision + 1,
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
