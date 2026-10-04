// W-05-02 (step 2 duplicate panel, weak GPS, permission denied), W-05-03
// (sensitive step 3), W-05-04 (error summary mapping), W-05-05 (done screen).
import 'package:flutter/material.dart' hide ErrorSummary;
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/api/app_error.dart';
import 'package:saarthee/core/capture/evidence_capture.dart';
import 'package:saarthee/core/l10n/app_localizations_en.dart';
import 'package:saarthee/core/widgets/widgets.dart';
import 'package:saarthee/features/report/application/report_draft_controller.dart';
import 'package:saarthee/features/report/application/report_providers.dart';
import 'package:saarthee/features/report/presentation/report_errors.dart';
import 'package:saarthee/router/app_router.dart';

import 'report_fakes.dart';
import 'report_harness.dart';

NearbyIssue dup() => NearbyIssue(
  id: 'dup-1',
  categorySlug: 'garbage',
  status: 'reported',
  distanceM: 30,
  meTooCount: 2,
  createdAt: DateTime(2026, 9, 24),
  wardNameEn: 'Paldi',
  wardNameGu: 'પાલડી',
);

void main() {
  group('W-05-02 step 2', () {
    testWidgets(
      'duplicate card: Add me too records it, discards the draft, confirms',
      (t) async {
        final api = FakeReportApi()..nearbyItems = [dup()];
        final c = await pumpReportApp(
          t,
          api: api,
          draft: draftAt(ReportStep.photo),
        );
        expect(find.byKey(const Key('report.wardLabel')), findsOneWidget);
        expect(find.text('In ward: Paldi (West zone)'), findsOneWidget);
        expect(find.text('Already reported nearby'), findsOneWidget);
        expect(find.text('30 m away · 2 me too'), findsOneWidget);
        await tapVisible(t, find.byKey(const Key('report.dup.addMeToo')));
        await t.pumpAndSettle();
        await t.pump(const Duration(seconds: 1));
        await t.pumpAndSettle();
        expect(api.meToos, ['dup-1']);
        expect(
          find.byKey(const Key('report.dup.confirmation')),
          findsOneWidget,
        );
        expect(c.read(reportDraftProvider), isNull);
      },
    );

    testWidgets('"No, mine is different" hides the card and keeps the draft', (
      t,
    ) async {
      final api = FakeReportApi()..nearbyItems = [dup()];
      final c = await pumpReportApp(
        t,
        api: api,
        draft: draftAt(ReportStep.photo),
      );
      await tapVisible(t, find.byKey(const Key('report.dup.different')));
      await t.pumpAndSettle();
      expect(find.text('Already reported nearby'), findsNothing);
      expect(c.read(reportDraftProvider)!.dismissedDuplicateIds, ['dup-1']);
      await tapVisible(t, find.byKey(const Key('report.continue')));
      await t.pumpAndSettle();
      expect(c.read(reportDraftProvider)!.step, ReportStep.details);
    });

    testWidgets('weak GPS shows the drag hint', (t) async {
      await pumpReportApp(
        t,
        api: FakeReportApi(),
        draft: draftAt(ReportStep.photo, accuracy: 80),
      );
      expect(
        find.text('Location is approximate. Drag the pin to the exact spot.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'permission denied: message, Open settings, Continue disabled',
      (t) async {
        final capture = FakeEvidenceCapture(
          access: LocationAccess.denied,
          autoPhoto: false,
        );
        final d = draftAt(ReportStep.photo);
        final noPin = ReportDraft(
          clientSubmissionId: d.clientSubmissionId,
          categorySlug: d.categorySlug,
          photos: d.photos,
          step: ReportStep.photo,
        );
        await pumpReportApp(
          t,
          api: FakeReportApi(),
          draft: noPin,
          capture: capture,
        );
        expect(
          find.text('We need your location to place the report on the map.'),
          findsOneWidget,
        );
        expect(find.text('Open settings'), findsOneWidget);
        final btn = t.widget<PrimaryButton>(
          find.byKey(const Key('report.continue')),
        );
        expect(btn.onPressed, isNull);
      },
    );

    testWidgets('a new draft opens the camera on entry', (t) async {
      final capture = FakeEvidenceCapture();
      final api = FakeReportApi();
      final d = draftAt(ReportStep.photo);
      final empty = ReportDraft(
        clientSubmissionId: d.clientSubmissionId,
        categorySlug: 'roads',
        step: ReportStep.photo,
      );
      final c = await pumpReportApp(
        t,
        api: api,
        draft: empty,
        capture: capture,
        reduced: true,
        settle: false,
      );
      // Real file IO (copy, blur render) runs outside fake async.
      for (var i = 0; i < 20 && api.uploads.isEmpty; i++) {
        await t.pump(const Duration(milliseconds: 50));
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
      }
      await t.pump();
      expect(capture.cameraOpens, 1);
      expect(c.read(reportDraftProvider)!.photos, hasLength(1));
      expect(api.uploads.single, endsWith('blur=false'));
      expect(c.read(reportDraftProvider)!.photos.single.uploaded, isTrue);
    });
  });

  group('W-05-03 step 3', () {
    testWidgets(
      'sensitive category: structured choices, no text field; Change links',
      (t) async {
        final c = await pumpReportApp(
          t,
          api: FakeReportApi(),
          draft: draftAt(ReportStep.details, slug: 'encroachment'),
        );
        expect(find.byKey(const Key('report.reasons')), findsOneWidget);
        expect(find.byKey(const Key('report.description')), findsNothing);
        expect(find.text('Blocking the footpath'), findsOneWidget);
        expect(
          find.text(
            'Your report, photos and place will be public. Your name and phone number are never shown.',
          ),
          findsOneWidget,
        );
        await tapVisible(t, find.text('Change').first);
        await t.pumpAndSettle();
        expect(c.read(reportDraftProvider)!.step, ReportStep.what);
      },
    );

    testWidgets(
      'non-sensitive: description field with counter; submit → done',
      (t) async {
        final api = FakeReportApi();
        await pumpReportApp(t, api: api, draft: draftAt(ReportStep.details));
        await t.enterText(
          find.byKey(const Key('report.description')),
          'Bins overflowing',
        );
        await t.pump();
        expect(find.text('16/1,000'), findsOneWidget);
        await tapVisible(t, find.byKey(const Key('report.submit')));
        await t.pumpAndSettle();
        expect(api.submits.single['description'], 'Bins overflowing');
        expect(api.submits.single['photoIds'], ['photo-1']);
        expect(find.byKey(const Key('report.done')), findsOneWidget);
      },
    );
  });

  group('W-05-04 error summary', () {
    final l10n = AppLocalizationsEn();
    AppError e(String code, [List<AppErrorDetail> d = const []]) =>
        AppError(code: code, details: d);

    test('maps each server code to copy and the step that fixes it', () {
      expect(reportError(l10n, e('PHOTO_UNUSABLE')).step, ReportStep.photo);
      expect(
        reportError(l10n, e('PHOTO_UNUSABLE')).message,
        'Your photo upload expired. Please retake the photo.',
      );
      expect(reportError(l10n, e('CATEGORY_INACTIVE')).step, ReportStep.what);
      expect(
        reportError(l10n, e('WARD_CONFIRMATION_REQUIRED')).step,
        ReportStep.photo,
      );
      expect(
        reportError(l10n, e('OUTSIDE_SERVICE_AREA')).step,
        ReportStep.photo,
      );
      expect(
        reportError(
          l10n,
          e('RATE_LIMITED', const [
            AppErrorDetail(field: 'quota', issue: 'issues_per_day'),
          ]),
        ).message,
        "You've sent 10 reports today. You can send more tomorrow.",
      );
      expect(
        reportError(
          l10n,
          e('VALIDATION_FAILED', const [
            AppErrorDetail(field: 'description', issue: 'x'),
          ]),
        ).step,
        ReportStep.details,
      );
      expect(
        reportError(l10n, e('ACCOUNT_SUSPENDED')).message,
        'This account is suspended.',
      );
    });

    testWidgets(
      'submit error shows the summary, focuses it and links to the step',
      (t) async {
        final api = FakeReportApi()
          ..submitError = const AppError(
            code: 'PHOTO_UNUSABLE',
            statusCode: 422,
          );
        final c = await pumpReportApp(
          t,
          api: api,
          draft: draftAt(ReportStep.details),
        );
        await tapVisible(t, find.byKey(const Key('report.submit')));
        await t.pumpAndSettle();
        expect(find.byType(ErrorSummary), findsOneWidget);
        expect(c.read(reportDraftProvider), isNotNull, reason: 'draft kept');
        await t.tap(
          find.text('Your photo upload expired. Please retake the photo.'),
        );
        await t.pumpAndSettle();
        expect(c.read(reportDraftProvider)!.step, ReportStep.photo);
      },
    );
  });

  group('W-05-05 done screen', () {
    Future<void> submitAndOpen(
      WidgetTester t, {
      String slug = 'roads',
      String lang = 'en',
    }) async {
      final api = FakeReportApi();
      final c = await pumpReportApp(
        t,
        api: api,
        draft: draftAt(ReportStep.details, slug: slug),
      );
      if (slug == 'encroachment' || slug == 'building') {
        await tapVisible(
          t,
          find.byKey(
            ValueKey('report.reason.${slug == 'building' ? 'unsafe' : 'road'}'),
          ),
        );
        await t.pump();
      }
      await tapVisible(t, find.byKey(const Key('report.submit')));
      await t.pumpAndSettle();
      expect(
        c.read(appRouterProvider).routerDelegate.currentConfiguration.uri.path,
        '/report/done',
      );
    }

    testWidgets(
      'primary AMC type in English, independence line, issue number',
      (t) async {
        await submitAndOpen(t);
        expect(find.text('Report sent. Thank you.'), findsOneWidget);
        expect(find.text('Issue SA-3F9A2C1B'), findsOneWidget);
        await t.scrollUntilVisible(
          find.byKey(const Key('report.done.amcType')),
          100,
        );
        expect(
          find.text(
            "AMC's category for this: Engineering › Road-Repair Require",
          ),
          findsOneWidget,
        );
        await t.scrollUntilVisible(
          find.text('Independent citizen app. Not run by or linked to AMC.'),
          100,
        );
        expect(
          find.text('Independent citizen app. Not run by or linked to AMC.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('category other → choose the closest type on AMC\'s site', (
      t,
    ) async {
      await submitAndOpen(t, slug: 'other');
      await t.scrollUntilVisible(
        find.byKey(const Key('report.done.amcType')),
        100,
      );
      expect(
        find.text("Choose the closest type on AMC's site."),
        findsOneWidget,
      );
    });

    testWidgets('sensitive → moderator copy', (t) async {
      await submitAndOpen(t, slug: 'encroachment');
      expect(
        find.text('A moderator will check it before it is public.'),
        findsOneWidget,
      );
    });
  });
}
