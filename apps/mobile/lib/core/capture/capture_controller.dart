import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'evidence_capture.dart';

/// State of one capture attempt: permission, camera, GPS fix, preview.
class CaptureState {
  const CaptureState({
    this.access,
    this.busy = false,
    this.photo,
    this.fix,
    this.locationFailed = false,
    this.weakAccepted = false,
  });

  final LocationAccess? access;
  final bool busy;

  /// Photo awaiting "Use this photo".
  final CapturedPhoto? photo;
  final Fix? fix;
  final bool locationFailed;
  final bool weakAccepted;

  bool get blockedByPermission =>
      access != null && access != LocationAccess.granted;

  /// The preview can be used: we have a fix that is good or accepted.
  bool get canUse =>
      photo != null && fix != null && (!fix!.isWeak || weakAccepted);

  CaptureState copy({
    LocationAccess? access,
    bool? busy,
    CapturedPhoto? photo,
    Fix? fix,
    bool? locationFailed,
    bool? weakAccepted,
    bool clearFix = false,
  }) => CaptureState(
    access: access ?? this.access,
    busy: busy ?? this.busy,
    photo: photo ?? this.photo,
    fix: clearFix ? null : (fix ?? this.fix),
    locationFailed: locationFailed ?? this.locationFailed,
    weakAccepted: weakAccepted ?? this.weakAccepted,
  );
}

/// Camera + location flow shared by report step 4 and verify photo
/// (02 §4.7, §4.14). Location is required (PRD Q6 undecided).
class CaptureController extends Notifier<CaptureState> {
  EvidenceCapture get _capture => ref.read(evidenceCaptureProvider);

  @override
  CaptureState build() => const CaptureState();

  /// Checks location permission without prompting (for returning from
  /// settings).
  Future<void> refreshAccess() async {
    final access = await _capture.locationAccess(request: false);
    state = state.copy(access: access);
  }

  Future<void> openSettings() async {
    final access = state.access;
    if (access != null) await _capture.openSettings(access);
  }

  Future<void> takePhoto() async {
    if (state.busy) return;
    state = state.copy(busy: true);
    final access = await _capture.locationAccess();
    if (access != LocationAccess.granted) {
      state = CaptureState(access: access);
      return;
    }
    final photo = await _capture.takePhoto();
    if (photo == null) {
      state = state.copy(busy: false, access: access);
      return;
    }
    state = CaptureState(access: access, busy: true, photo: photo);
    await _readFix();
  }

  Future<void> retryLocation() async {
    if (state.photo == null || state.busy) return;
    state = state.copy(busy: true, locationFailed: false, clearFix: true);
    await _readFix();
  }

  Future<void> _readFix() async {
    final fix = await _capture.currentFix();
    state = CaptureState(
      access: state.access,
      photo: state.photo,
      fix: fix,
      locationFailed: fix == null,
    );
  }

  void acceptWeak() => state = state.copy(weakAccepted: true);

  void reset() => state = CaptureState(access: state.access);
}

final captureControllerProvider =
    NotifierProvider.autoDispose<CaptureController, CaptureState>(
      CaptureController.new,
    );
