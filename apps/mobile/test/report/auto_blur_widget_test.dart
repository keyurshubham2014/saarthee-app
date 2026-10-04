// W-05-15 (AC-11, REQ-S-007): the photo step after automatic blurring, and
// the manual-tool fallback when detection fails.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:saarthee/core/capture/blur/face_plate_detector.dart';
import 'package:saarthee/core/capture/evidence_capture.dart';
import 'package:saarthee/features/report/application/report_draft_controller.dart';
import 'package:saarthee/router/app_router.dart';

import 'auto_detector_test.dart' show FakeDetector;
import 'report_fakes.dart';
import 'report_harness.dart';

const _blurred = 'Faces and number plates blurred';
const _unavailable =
    'Automatic blurring isn\'t available on this phone. '
    'Blur faces and number plates by hand.';

/// A camera that returns a fine 96×96 checkerboard, so pixelation shows.
class CheckerCapture extends FakeEvidenceCapture {
  @override
  Future<CapturedPhoto?> takePhoto() async {
    cameraOpens++;
    final im = img.Image(width: 96, height: 96);
    for (var y = 0; y < 96; y++) {
      for (var x = 0; x < 96; x++) {
        final v = (x + y).isEven ? 240 : 20;
        im.setPixelRgb(x, y, v, v, v);
      }
    }
    final dir = Directory.systemTemp.createTempSync('auto-blur');
    final f = File('${dir.path}/checker.jpg')
      ..writeAsBytesSync(img.encodeJpg(im, quality: 100));
    return CapturedPhoto(path: f.path, capturedAt: DateTime(2026, 10, 4));
  }
}

/// Opens the photo step on an empty draft; the fake camera returns a photo
/// that goes through detect → blur → upload.
Future<(ProviderContainer, FakeReportApi)> captureWith(
  WidgetTester t,
  FaceAndPlateDetector detector,
) async {
  final api = FakeReportApi();
  final d = draftAt(ReportStep.photo);
  final c = await pumpReportApp(
    t,
    api: api,
    draft: ReportDraft(
      clientSubmissionId: d.clientSubmissionId,
      categorySlug: 'roads',
      step: ReportStep.photo,
    ),
    capture: CheckerCapture(),
    reduced: true,
    settle: false,
    extraOverrides: [faceAndPlateDetectorProvider.overrideWithValue(detector)],
  );
  // Real file IO (orientation, blur render) runs outside fake async.
  for (var i = 0; i < 40 && api.uploads.isEmpty; i++) {
    await t.pump(const Duration(milliseconds: 50));
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
  }
  await t.pumpAndSettle();
  return (c, api);
}

/// Mean absolute difference between neighbouring pixels in a square.
double roughness(String path, int x0, int x1) {
  final im = img.decodeJpg(File(path).readAsBytesSync())!;
  var sum = 0.0;
  var n = 0;
  for (var y = x0; y < x1; y++) {
    for (var x = x0; x < x1 - 1; x++) {
      sum += (im.getPixel(x, y).r - im.getPixel(x + 1, y).r).abs();
      n++;
    }
  }
  return sum / n;
}

void main() {
  testWidgets('auto-blur: boxes pixelated before upload, caption shown', (
    t,
  ) async {
    final detector = FakeDetector(const [BlurBox(0, 0, 0.5, 0.5)]);
    final (c, api) = await captureWith(t, detector);
    expect(detector.calls, hasLength(1));
    expect(api.uploads.single, endsWith('blur=true'));
    final photo = c.read(reportDraftProvider)!.photos.single;
    expect(photo.blurApplied, isTrue);
    expect(find.text(_blurred), findsOneWidget);
    // The uploaded file is the blurred one: the box area is flat.
    final inside = await t.runAsync(
      () async => roughness(photo.localPath, 2, 10),
    );
    final outside = await t.runAsync(
      () async => roughness(photo.localPath, 60, 90),
    );
    expect(inside, lessThan(12));
    expect(outside, greaterThan(80));
  });

  testWidgets('detector fails: unblurred flag, manual tool with its note', (
    t,
  ) async {
    final detector = FakeDetector(null, error: StateError('ML Kit down'));
    final (c, api) = await captureWith(t, detector);
    expect(api.uploads.single, endsWith('blur=false'));
    expect(find.text(_blurred), findsNothing);
    final path = c.read(reportDraftProvider)!.photos.single.localPath;
    c
        .read(appRouterProvider)
        .go(
          Uri(
            path: '/report/photo/blur',
            queryParameters: {'path': path},
          ).toString(),
        );
    await t.pumpAndSettle();
    expect(find.byKey(const Key('report.blur.note')), findsOneWidget);
    expect(find.text(_unavailable), findsOneWidget);
  });

  testWidgets('auto-blur ran: blur screen offers "Tap or drag to blur more"', (
    t,
  ) async {
    final (c, _) = await captureWith(t, FakeDetector(const []));
    final path = c.read(reportDraftProvider)!.photos.single.localPath;
    c
        .read(appRouterProvider)
        .go(
          Uri(
            path: '/report/photo/blur',
            queryParameters: {'path': path},
          ).toString(),
        );
    await t.pumpAndSettle();
    expect(find.text('Tap or drag to blur more'), findsOneWidget);
  });
}
