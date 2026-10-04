import 'dart:io';
import 'dart:ui' show Rect, Size;

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart'
    as mlf;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'
    as mlt;
import 'package:image/image.dart' as img;

import 'face_plate_detector.dart';

/// Face boxes in image pixels.
abstract interface class FaceBoxSource {
  Future<List<Rect>> faces(String imagePath);
  Future<void> close();
}

/// Recognised text blocks (text + box in image pixels).
abstract interface class TextBlockSource {
  Future<List<(String, Rect)>> blocks(String imagePath);
  Future<void> close();
}

/// Reads the pixel size of a JPEG from its header (no full decode).
Future<Size?> jpegSize(String path) async {
  final bytes = await File(path).readAsBytes();
  final info = img.JpegDecoder().startDecode(bytes);
  if (info == null) return null;
  return Size(info.width.toDouble(), info.height.toDouble());
}

/// Faces + plate-like text → padded [BlurBox]es (fractions of the image).
/// Any failure (plugin missing, ML Kit error, unreadable file) returns null
/// so the flow falls back to the manual tool (REQ-S-007).
class AutoFaceAndPlateDetector implements FaceAndPlateDetector {
  AutoFaceAndPlateDetector({
    required this.faces,
    required this.text,
    this.sizeOf = jpegSize,
    this.padding = 0.15,
  });

  final FaceBoxSource faces;
  final TextBlockSource text;
  final Future<Size?> Function(String path) sizeOf;

  /// Grow every box by this fraction per side (about 15 %).
  final double padding;

  @override
  Future<List<BlurBox>?> detect(String imagePath) async {
    try {
      final size = await sizeOf(imagePath);
      if (size == null || size.isEmpty) return null;
      BlurBox frac(Rect r) => BlurBox(
        r.left / size.width,
        r.top / size.height,
        r.width / size.width,
        r.height / size.height,
      );
      final results = await Future.wait([
        faces.faces(imagePath),
        text
            .blocks(imagePath)
            .then(
              (blocks) => plateBoxes([
                for (final (t, r) in blocks) TextBlockBox(t, frac(r)),
              ], imageAspect: size.width / size.height),
            ),
      ]);
      final faceBoxes = [for (final r in results[0] as List<Rect>) frac(r)];
      final plates = results[1] as List<BlurBox>;
      return [
        for (final b in [...faceBoxes, ...plates])
          if (b.width > 0 && b.height > 0) b.padded(padding),
      ];
    } on Object {
      return null;
    }
  }

  Future<void> close() async {
    await faces.close();
    await text.close();
  }
}

/// ML Kit face detection (bundled model, accurate mode, faces ≥ 5 % of the
/// image). Runs natively on ML Kit's own worker threads; the UI isolate only
/// awaits the platform channel.
class MlKitFaceBoxSource implements FaceBoxSource {
  final mlf.FaceDetector _detector = mlf.FaceDetector(
    options: mlf.FaceDetectorOptions(
      performanceMode: mlf.FaceDetectorMode.accurate,
      minFaceSize: 0.05,
    ),
  );

  @override
  Future<List<Rect>> faces(String imagePath) async => [
    for (final f in await _detector.processImage(
      mlf.InputImage.fromFilePath(imagePath),
    ))
      f.boundingBox,
  ];

  @override
  Future<void> close() => _detector.close();
}

/// ML Kit Latin text recognition (bundled model).
class MlKitTextBlockSource implements TextBlockSource {
  final mlt.TextRecognizer _recognizer = mlt.TextRecognizer(
    script: mlt.TextRecognitionScript.latin,
  );

  @override
  Future<List<(String, Rect)>> blocks(String imagePath) async {
    final r = await _recognizer.processImage(
      mlt.InputImage.fromFilePath(imagePath),
    );
    return [
      for (final b in r.blocks) ...[
        (b.text, b.boundingBox),
        // A block can hold a plate and other text; check lines too.
        if (b.lines.length > 1)
          for (final l in b.lines) (l.text, l.boundingBox),
      ],
    ];
  }

  @override
  Future<void> close() => _recognizer.close();
}
