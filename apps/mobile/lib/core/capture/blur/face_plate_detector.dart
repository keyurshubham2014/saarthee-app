import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'blur_renderer.dart';

export 'blur_renderer.dart';

/// Indian number-plate pattern applied to recognised text blocks
/// (TASK-05 §5.6), e.g. `GJ 01 AB 1234`.
final RegExp kIndianPlate = RegExp(
  r'^[A-Z]{2}\s?\d{1,2}\s?[A-Z]{0,3}\s?\d{4}$',
);

/// A text block found in a photo (fractions of the image size).
class TextBlockBox {
  const TextBlockBox(this.text, this.box);

  final String text;
  final BlurBox box;
}

/// Plate boxes among recognised text blocks.
List<BlurBox> plateBoxes(Iterable<TextBlockBox> blocks) => [
  for (final b in blocks)
    if (kIndianPlate.hasMatch(b.text.trim().toUpperCase())) b.box,
];

/// On-device face and number-plate detection (REQ-S-007). [detect] returns
/// null when no detector is available on this phone; the report flow then
/// offers the manual blur tool only, with the "isn't available" note.
abstract interface class FaceAndPlateDetector {
  Future<List<BlurBox>?> detect(String imagePath);
}

/// Default until an ML Kit detector is wired in by the integrator (TASK-05
/// §13: ML Kit plugins could not be build-verified against AGP 9 in this
/// worker; the manual tool always works).
class UnavailableDetector implements FaceAndPlateDetector {
  const UnavailableDetector();

  @override
  Future<List<BlurBox>?> detect(String imagePath) async => null;
}

final faceAndPlateDetectorProvider = Provider<FaceAndPlateDetector>(
  (ref) => const UnavailableDetector(),
);
