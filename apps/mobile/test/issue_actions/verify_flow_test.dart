// W-06-01 (AC-4, AC-12), W-06-08 (AC-14, AC-15), W-06-09 (AC-12, AC-14): verify flow.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/api/app_error.dart';
import 'package:saarthee/core/capture/evidence_capture.dart';
import 'package:saarthee/core/l10n/app_localizations.dart';
import 'package:saarthee/core/motion/motion_check.dart';
import 'package:saarthee/core/theme/motion.dart';
import 'package:saarthee/features/issue_actions/data/issue_actions_api.dart';
import 'package:saarthee/features/issue_actions/data/issue_models.dart';
import 'package:saarthee/features/issue_actions/presentation/verify_photo_screen.dart';

import '../helpers/fake_haptics.dart';
import '../report/report_fakes.dart';
import 'fakes.dart';
import 'harness.dart';

Fix _north(double metres, {double accuracy = 8}) => Fix(
  latitude: 23.0225 + metres / 111195,
  longitude: 72.5714,
  accuracy: accuracy,
);

const _send = Key('issueActions.send');
const _photoPath = '/issues/$kIssueId/verify/photo?answer=fixed';

FilledButton _sendButton(WidgetTester t) =>
    t.widget<FilledButton>(find.byKey(_send));

double _check(WidgetTester t) =>
    (t
                .widget<CustomPaint>(
                  find.descendant(
                    of: find.byType(MotionCheck),
                    matching: find.byType(CustomPaint),
                  ),
                )
                .painter!
            as CheckPainter)
        .progress;

Future<void> _takePhoto(WidgetTester t) async {
  await t.tap(find.byKey(const Key('verify.take')));
  await settle(t);
}

void main() {
  group('W-06-01 step 2 distance states', () {
    testWidgets('near: live distance and Send enabled', (t) async {
      await pumpIssueRoutes(
        t,
        initial: _photoPath,
        capture: FakeEvidenceCapture(fix: _north(30)),
      );
      expect(find.text('Step 2 of 2'), findsOneWidget);
      expect(_sendButton(t).onPressed, isNull);
      await _takePhoto(t);
      expect(find.text("You're about 30 m from the problem."), findsOneWidget);
      expect(_sendButton(t).onPressed, isNotNull);
    });

    testWidgets('too far: 240 m copy and Send disabled', (t) async {
      await pumpIssueRoutes(
        t,
        initial: _photoPath,
        capture: FakeEvidenceCapture(fix: _north(240)),
      );
      await _takePhoto(t);
      expect(
        find.text(
          "You need to be within 100 m of the problem to verify. You're about 240 m away.",
        ),
        findsOneWidget,
      );
      expect(_sendButton(t).onPressed, isNull);
    });

    testWidgets('inaccurate GPS: approximate copy and Send disabled', (
      t,
    ) async {
      await pumpIssueRoutes(
        t,
        initial: _photoPath,
        capture: FakeEvidenceCapture(fix: _north(10, accuracy: 80)),
      );
      await _takePhoto(t);
      expect(
        find.text('Location is approximate. Move into the open and try again.'),
        findsOneWidget,
      );
      expect(_sendButton(t).onPressed, isNull);
    });
  });

  group('W-06-08 Send → progress → toast → Verified', () {
    Future<(FakeIssueActionsApi, FakeSaartheeHaptics)> start(
      WidgetTester t, {
      bool? reduced,
    }) async {
      final api = FakeIssueActionsApi(issue: sampleIssue());
      final haptics = FakeSaartheeHaptics();
      await pumpIssueRoutes(
        t,
        initial: '/issues/$kIssueId',
        api: api,
        haptics: haptics,
        reduced: reduced,
        capture: FakeEvidenceCapture(fix: _north(30)),
      );
      expect(
        find.byKey(const ValueKey('statusChip.markedFixed')),
        findsOneWidget,
      );
      await t.tap(find.byKey(const Key('lifecycle.verify')));
      await settle(t);
      await t.tap(find.byKey(const Key('verify.yes')));
      await settle(t);
      await _takePhoto(t);
      return (api, haptics);
    }

    testWidgets(
      'in-button progress while sending, then toast with drawn check and Verified chip',
      (t) async {
        final (api, haptics) = await start(t);
        final gate = Completer<VerifyResult>();
        api.verifyGate = gate;
        haptics.calls.clear();
        await t.tap(find.byKey(_send));
        await t.pump();
        await t.pump(SaartheeMotion.short.duration);
        await t.pump(SaartheeMotion.short.duration);
        expect(
          find.descendant(
            of: find.byKey(_send),
            matching: find.byType(LinearProgressIndicator),
          ),
          findsOneWidget,
        );
        expect(find.text('Send'), findsNothing);
        expect(_sendButton(t).onPressed, isNull);
        expect(haptics.calls, ['light']);
        expect(api.verifyCalls.single, containsPair('answer', 'fixed'));

        api.issue = sampleIssue(
          status: 'verified',
          actions: const ViewerActions(),
        );
        api.eventList = [
          ...api.eventList,
          ev('v', 'status_change', to: 'verified', actor: 'system'),
        ];
        gate.complete(
          const VerifyResult(status: 'verified', displayStatus: 'verified'),
        );
        await t.pump();
        await t.pump();
        expect(find.byKey(const Key('toast')), findsOneWidget);
        expect(
          find.text("Thanks for checking. It's now Verified."),
          findsOneWidget,
        );
        await t.pump(SaartheeMotion.springIn.duration);
        await t.pump(
          SaartheeMotion.drawCheckDelay + SaartheeMotion.drawCheck.duration,
        );
        expect(_check(t), 1);
        await settle(t);
        expect(
          find.byKey(const ValueKey('statusChip.verified')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('verify.take')), findsNothing);
        // Toast gone 4 s after it appeared (hold, then a `medium` exit).
        await t.pump(SaartheeMotion.toastHold);
        await settle(t);
        expect(find.byKey(const Key('toast')), findsNothing);
      },
    );

    testWidgets('failure: button restored with the error and no toast', (
      t,
    ) async {
      final (api, _) = await start(t);
      api.verifyError = const AppError(code: 'ALREADY_ANSWERED_TODAY');
      await t.tap(find.byKey(_send));
      await settle(t);
      expect(find.text('Send'), findsOneWidget);
      expect(
        find.text("You've already answered today. Thank you."),
        findsOneWidget,
      );
      expect(find.byKey(const Key('toast')), findsNothing);
    });

    testWidgets(
      'reduced motion: toast check and chip are final on the first frame',
      (t) async {
        final (api, _) = await start(t, reduced: true);
        api.issue = sampleIssue(
          status: 'verified',
          actions: const ViewerActions(),
        );
        await t.tap(find.byKey(_send));
        await t.pump();
        await t.pump();
        expect(find.byKey(const Key('toast')), findsOneWidget);
        expect(_check(t), 1);
        await settle(t);
        expect(
          find.byKey(const ValueKey('statusChip.verified')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('statusChip.markedFixed')),
          findsNothing,
        );
      },
    );
  });

  group('W-06-09', () {
    testWidgets('/issues/:id/verify/done redirects to the issue', (t) async {
      final h = await pumpIssueRoutes(
        t,
        initial: '/issues/$kIssueId/verify/done',
      );
      expect(
        h.router.routerDelegate.currentConfiguration.uri.path,
        '/issues/$kIssueId',
      );
    });

    testWidgets('v1 /verify/<token> links open Home', (t) async {
      await pumpIssueRoutes(t, initial: '/verify/abc123');
      expect(find.byKey(homeKey), findsOneWidget);
    });

    testWidgets('window closed: step 1 says it can no longer be checked', (
      t,
    ) async {
      final api = FakeIssueActionsApi(
        issue: sampleIssue(
          closes: DateTime.now().subtract(const Duration(days: 1)),
          displayStatus: 'fixed_unverified',
        ),
      );
      await pumpIssueRoutes(t, initial: '/issues/$kIssueId/verify', api: api);
      expect(find.text('This issue can no longer be checked.'), findsOneWidget);
      expect(find.byKey(const Key('verify.yes')), findsNothing);
    });

    test('outcome toast copy in en and gu', () {
      final en = lookupAppLocalizations(const Locale('en'));
      final gu = lookupAppLocalizations(const Locale('gu'));
      expect(
        verifyOutcomeMessage(en, 'verified'),
        "Thanks for checking. It's now Verified.",
      );
      expect(
        verifyOutcomeMessage(en, 'reopened'),
        "Thanks for checking. It's been reopened.",
      );
      expect(
        verifyOutcomeMessage(en, 'marked_fixed'),
        'Thanks for checking. Your answer is recorded.',
      );
      for (final s in ['verified', 'reopened', 'marked_fixed']) {
        expect(verifyOutcomeMessage(gu, s), startsWith('તપાસવા બદલ આભાર.'));
      }
    });
  });
}
