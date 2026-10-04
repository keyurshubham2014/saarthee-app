import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/settings/motion_preference.dart';
import 'package:saarthee/features/report/application/report_draft_controller.dart';
import 'package:saarthee/router/app_router.dart';

import '../helpers/app.dart';
import '../helpers/fake_haptics.dart';
import '../helpers/fake_wards.dart';
import 'report_fakes.dart';

/// A draft at [step] with one uploaded photo and a pin in Paldi.
ReportDraft draftAt(
  ReportStep step, {
  String slug = 'garbage',
  bool uploaded = true,
  double accuracy = 8,
}) => ReportDraft(
  clientSubmissionId: '7d9b4c1e-0000-4000-8000-00000000000a',
  categorySlug: slug,
  photos: [
    DraftPhoto(
      localPath: writeTestJpeg(),
      capturedAt: DateTime(2026, 10, 3, 14, 19),
      photoId: uploaded ? 'photo-1' : null,
      uploadState: uploaded ? UploadState.uploaded : UploadState.pending,
      blurApplied: true,
    ),
  ],
  fix: LatLngFix(lat: 23.0225, lng: 72.5714, accuracyM: accuracy),
  pin: LatLngFix(lat: 23.0225, lng: 72.5714, accuracyM: accuracy),
  step: step,
);

/// Pumps the app on `/report` with fakes; [draft] is stored before launch.
Future<ProviderContainer> pumpReportApp(
  WidgetTester t, {
  required FakeReportApi api,
  ReportDraft? draft,
  FakeEvidenceCapture? capture,
  FakeWardsRepository? wards,
  FakeSaartheeHaptics? haptics,
  bool? reduced,
  String location = '/report',
  bool settle = true,
  Size size = const Size(400, 900),
  List extraOverrides = const [],
}) async {
  final c = await pumpApp(
    t,
    size: size,
    haptics: haptics,
    prefs: {
      ...onboardedPrefs(),
      if (draft != null) kReportDraftKey: draft.encode(),
    },
    overrides: [
      ...reportOverrides(
        api: api,
        capture: capture ?? FakeEvidenceCapture(autoPhoto: false),
        wards: wards,
      ),
      if (reduced != null) reducedMotionProvider.overrideWithValue(reduced),
      ...extraOverrides,
    ],
  );
  c.read(appRouterProvider).go(location);
  if (settle) {
    await t.pumpAndSettle();
    // Duplicate check debounce (500 ms) and ward lookup.
    await t.pump(const Duration(milliseconds: 600));
    await t.pumpAndSettle();
  }
  return c;
}

Future<void> tapVisible(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
}
