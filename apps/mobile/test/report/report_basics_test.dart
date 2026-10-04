// W-05-01 (category grid states), W-05-06 (draft v2 restore / v1 discard),
// issueRef unit cases (W-05-12 part), S-05-02 (sunrise only on Submit).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/api/app_error.dart';
import 'package:saarthee/core/format/issue_ref.dart';
import 'package:saarthee/core/settings/app_settings.dart';
import 'package:saarthee/features/report/application/report_draft_controller.dart';
import 'package:saarthee/features/report/application/report_providers.dart';
import 'package:saarthee/router/app_router.dart';

import '../helpers/app.dart';
import '../helpers/motion.dart';
import 'report_fakes.dart';

Future<ProviderContainer> openReport(
  WidgetTester t, {
  required FakeReportApi api,
  Map<String, Object> prefs = const {},
  FakeEvidenceCapture? capture,
}) async {
  final c = await pumpApp(
    t,
    prefs: {...onboardedPrefs(), ...prefs},
    overrides: reportOverrides(api: api, capture: capture),
  );
  c.read(appRouterProvider).go('/report');
  await t.pumpAndSettle();
  return c;
}

void main() {
  group('W-05-01 category grid', () {
    testWidgets('renders 14 tiles from the provider', (t) async {
      await openReport(t, api: FakeReportApi());
      expect(find.text('What is the problem?'), findsOneWidget);
      for (final s in kSlugs) {
        final tile = find.byKey(ValueKey('report.tile.$s'));
        await t.scrollUntilVisible(
          tile,
          100,
          scrollable: find.byType(Scrollable).last,
        );
        expect(tile, findsOneWidget, reason: s);
      }
    });

    testWidgets('error state offers Try again', (t) async {
      final api = FakeReportApi()
        ..categoriesError = const AppError(code: 'INTERNAL_ERROR');
      await openReport(t, api: api);
      expect(find.text("We couldn't load the list. Try again"), findsOneWidget);
      api.categoriesError = null;
      await t.tap(find.text('Try again'));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('report.tile.roads')), findsOneWidget);
    });

    testWidgets('offline → cached list with the offline note', (t) async {
      final api = FakeReportApi()..categoriesError = const AppError.offline();
      final cached = jsonEncode([for (final c in fakeCategories()) c.toJson()]);
      await openReport(t, api: api, prefs: {kCategoriesCacheKey: cached});
      expect(
        find.text("You're offline. Showing the saved list."),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('report.tile.roads')), findsOneWidget);
    });

    testWidgets('skeleton while loading', (t) async {
      final api = FakeReportApi()..categoriesGate = Completer<void>();
      final c = await pumpApp(
        t,
        prefs: onboardedPrefs(),
        overrides: reportOverrides(api: api),
      );
      c.read(appRouterProvider).go('/report');
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('report.what.skeleton')), findsOneWidget);
      api.categoriesGate!.complete();
      await t.pumpAndSettle();
      expect(find.byKey(const Key('report.what.skeleton')), findsNothing);
      expect(find.byKey(const ValueKey('report.tile.roads')), findsOneWidget);
    });
  });

  group('W-05-06 draft persistence', () {
    test('restores a v2 draft from JSON', () async {
      final draft = ReportDraft(
        clientSubmissionId: 'c5d0a6f2-0000-4000-8000-000000000001',
        categorySlug: 'garbage',
        photos: [
          DraftPhoto(
            localPath: '/tmp/a.jpg',
            capturedAt: DateTime(2026, 10, 3),
            photoId: 'p1',
            uploadState: UploadState.uploaded,
          ),
        ],
        fix: const LatLngFix(lat: 23.0225, lng: 72.5714, accuracyM: 8),
        pin: const LatLngFix(lat: 23.0226, lng: 72.5714),
        pinAdjusted: true,
        step: ReportStep.photo,
      );
      final prefs = await testPrefs({kReportDraftKey: draft.encode()});
      final c = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(c.dispose);
      final restored = c.read(reportDraftProvider)!;
      expect(restored.categorySlug, 'garbage');
      expect(restored.step, ReportStep.photo);
      expect(restored.photos.single.uploaded, isTrue);
      expect(restored.pinAdjusted, isTrue);
      expect(restored.pin!.lat, 23.0226);
    });

    test('discards a v1 draft and its photo file', () async {
      final photo = File(writeTestJpeg('v1.jpg'));
      final v1 = jsonEncode({
        'categoryId': 'x',
        'photoPath': photo.path,
        'ccrsNumber': 'AMC-1',
      });
      final prefs = await testPrefs({kReportDraftKey: v1});
      final c = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(c.dispose);
      expect(c.read(reportDraftProvider), isNull);
      expect(prefs.getString(kReportDraftKey), isNull);
      expect(photo.existsSync(), isFalse);
    });

    test('every change is persisted', () async {
      final prefs = await testPrefs();
      final c = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(c.dispose);
      c.read(reportDraftProvider.notifier).chooseCategory('roads');
      c.read(reportDraftProvider.notifier).setDescription('Deep pothole');
      final stored = ReportDraft.decode(prefs.getString(kReportDraftKey)!)!;
      expect(stored.categorySlug, 'roads');
      expect(stored.description, 'Deep pothole');
      expect(stored.step, ReportStep.photo);
    });
  });

  test('issueRef: SA- + first 8 hex upper-cased', () {
    expect(issueRef('3f9a2c1b-1234-4000-8000-000000000001'), 'SA-3F9A2C1B');
    expect(issueRef('abc'), 'SA-ABC00000');
  });

  test('S-05-02 sunrise appears only on the Submit report button', () {
    final hits = <String>[];
    for (final f in Directory(
      'lib/features/report',
    ).listSync(recursive: true).whereType<File>()) {
      for (final line in f.readAsLinesSync()) {
        if (line.contains('sunrise') &&
            !line.trim().startsWith('//') &&
            !line.trim().startsWith('///')) {
          hits.add('${f.path}: $line');
        }
      }
    }
    expect(
      hits,
      isEmpty,
      reason: 'use SubmitReportButton only:\n${hits.join('\n')}',
    );
    final details = File('lib/features/report/presentation/step_details.dart')
        .readAsStringSync();
    expect('SubmitReportButton('.allMatches(details), hasLength(1));
  });
}
