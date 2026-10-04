// W-05-14 (AC-11, REQ-S-007): the automatic detector behind
// FaceAndPlateDetector, with fake face and text sources; the pipeline's
// timeout and fallback.
import 'dart:async';
import 'dart:ui' show Rect, Size;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/capture/blur/face_plate_detector.dart';
import 'package:saarthee/core/capture/blur/mlkit_detector.dart';
import 'package:saarthee/features/report/application/photo_pipeline.dart';

import 'report_fakes.dart';

class FakeFaces implements FaceBoxSource {
  FakeFaces(this.result, {this.error});
  final List<Rect> result;
  final Object? error;
  bool closed = false;

  @override
  Future<List<Rect>> faces(String imagePath) async {
    if (error != null) throw error!;
    return result;
  }

  @override
  Future<void> close() async => closed = true;
}

class FakeText implements TextBlockSource {
  FakeText(this.result);
  final List<(String, Rect)> result;
  bool closed = false;

  @override
  Future<List<(String, Rect)>> blocks(String imagePath) async => result;

  @override
  Future<void> close() async => closed = true;
}

/// A detector that returns [result], fails with [error], or never answers.
class FakeDetector implements FaceAndPlateDetector {
  FakeDetector(this.result, {this.never = false, this.error});
  final List<BlurBox>? result;
  final bool never;
  final Object? error;
  final List<String> calls = [];

  @override
  Future<List<BlurBox>?> detect(String imagePath) {
    calls.add(imagePath);
    if (never) return Completer<List<BlurBox>?>().future;
    if (error != null) return Future.error(error!);
    return Future.value(result);
  }
}

Future<Size?> size1000x500(String _) async => const Size(1000, 500);

void main() {
  group('AutoFaceAndPlateDetector', () {
    test('faces and plates → fractional boxes padded 15 % per side', () async {
      final d = AutoFaceAndPlateDetector(
        faces: FakeFaces([const Rect.fromLTWH(100, 100, 200, 200)]),
        text: FakeText([
          ('GJ 01 AB 1234', const Rect.fromLTWH(500, 300, 200, 50)),
          ('NO PARKING', const Rect.fromLTWH(600, 50, 300, 60)),
        ]),
        sizeOf: size1000x500,
      );
      final boxes = (await d.detect('/x.jpg'))!;
      expect(boxes, hasLength(2));
      final face = boxes[0];
      // 200 px wide face → 0.2, grown by 0.03 on each side.
      expect(face.left, closeTo(0.07, 1e-9));
      expect(face.width, closeTo(0.26, 1e-9));
      expect(face.top, closeTo(0.14, 1e-9));
      expect(face.height, closeTo(0.52, 1e-9));
      final plate = boxes[1];
      expect(plate.left, closeTo(0.47, 1e-9));
      expect(plate.width, closeTo(0.26, 1e-9));
    });

    test('nothing found → empty list (pass ran, nothing to blur)', () async {
      final d = AutoFaceAndPlateDetector(
        faces: FakeFaces(const []),
        text: FakeText([('SHOP OPEN', const Rect.fromLTWH(0, 0, 100, 40))]),
        sizeOf: size1000x500,
      );
      expect(await d.detect('/x.jpg'), isEmpty);
    });

    test('a failing source → null (manual tool fallback)', () async {
      final d = AutoFaceAndPlateDetector(
        faces: FakeFaces(const [], error: StateError('ML Kit down')),
        text: FakeText(const []),
        sizeOf: size1000x500,
      );
      expect(await d.detect('/x.jpg'), isNull);
    });

    test('unreadable image size → null', () async {
      final d = AutoFaceAndPlateDetector(
        faces: FakeFaces(const []),
        text: FakeText(const []),
        sizeOf: (_) async => null,
      );
      expect(await d.detect('/x.jpg'), isNull);
    });

    test('close() closes both sources', () async {
      final f = FakeFaces(const []);
      final t = FakeText(const []);
      await AutoFaceAndPlateDetector(faces: f, text: t).close();
      expect(f.closed && t.closed, isTrue);
    });

    test('jpegSize reads the header of a real JPEG', () async {
      expect(await jpegSize(writeTestJpeg()), const Size(64, 48));
    });
  });

  group('ReportPhotoPipeline.detectBoxes', () {
    Future<List<BlurBox>?> run(FaceAndPlateDetector d) {
      final c = ProviderContainer(
        overrides: [faceAndPlateDetectorProvider.overrideWithValue(d)],
      );
      addTearDown(c.dispose);
      return c
          .read(reportPhotoPipelineProvider)
          .detectBoxes(
            writeTestJpeg(),
            timeout: const Duration(milliseconds: 200),
          );
    }

    test('returns the detector boxes', () async {
      const box = BlurBox(0.1, 0.1, 0.2, 0.2);
      expect(await run(FakeDetector(const [box])), [box]);
    });

    test('timeout → null', () async {
      expect(await run(FakeDetector(null, never: true)), isNull);
    });

    test('detector error → null', () async {
      expect(await run(FakeDetector(null, error: StateError('x'))), isNull);
    });

    test('UnavailableDetector → null without calling it', () async {
      expect(await run(const UnavailableDetector()), isNull);
    });
  });
}
