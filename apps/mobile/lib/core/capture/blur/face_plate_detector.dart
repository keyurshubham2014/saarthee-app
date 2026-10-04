import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'blur_renderer.dart';
import 'mlkit_detector.dart';

export 'blur_renderer.dart';
export 'plate_heuristic.dart';

/// On-device face and number-plate detection (REQ-S-007). [detect] returns
/// null when no detector is available on this phone; the report flow then
/// offers the manual blur tool only, with the "isn't available" note.
abstract interface class FaceAndPlateDetector {
  Future<List<BlurBox>?> detect(String imagePath);
}

/// Used where ML Kit is not available (tests, desktop, web, iOS until it is
/// build-verified); the flow offers the manual blur tool with its note.
class UnavailableDetector implements FaceAndPlateDetector {
  const UnavailableDetector();

  @override
  Future<List<BlurBox>?> detect(String imagePath) async => null;
}

/// ML Kit face detection + plate heuristic on Android (verified by a debug
/// arm64 APK build); [UnavailableDetector] elsewhere.
final faceAndPlateDetectorProvider = Provider<FaceAndPlateDetector>((ref) {
  if (kIsWeb || !Platform.isAndroid) return const UnavailableDetector();
  final d = AutoFaceAndPlateDetector(
    faces: MlKitFaceBoxSource(),
    text: MlKitTextBlockSource(),
  );
  ref.onDispose(d.close);
  return d;
});
