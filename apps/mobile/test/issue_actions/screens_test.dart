// W-06-02 (AC-8) escalate, W-06-04 (AC-9) AMC closed it, W-06-05 (AC-1, AC-2) IssueStatusActions.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/api/app_error.dart';
import 'package:saarthee/core/utils/formatters.dart';
import 'package:saarthee/features/issue_actions/data/issue_actions_api.dart';
import 'package:saarthee/features/issue_actions/data/issue_models.dart';

import 'fakes.dart';
import 'harness.dart';

const _escalate = '/issues/$kIssueId/escalate';

void main() {
  group('W-06-02 escalate', () {
    testWidgets(
      'suggests corporators first; no corporator data → Copy/Share only; independence line',
      (t) async {
        final api = FakeIssueActionsApi(
          issue: sampleIssue(
            status: 'sent',
            actions: const ViewerActions(escalate: true),
          ),
        );
        final launcher = FakeLauncher();
        await pumpIssueRoutes(
          t,
          initial: _escalate,
          api: api,
          launcher: launcher,
        );
        await settle(t);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('escalate.level.corporators')),
            matching: find.byKey(const Key('escalate.suggested')),
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            'Saarthee prepares this message for you. It is not an official complaint.',
          ),
          findsOneWidget,
        );
        expect(
          api.escalations,
          isEmpty,
          reason: 'opening the screen logs nothing',
        );
        await t.tap(find.byKey(const ValueKey('escalate.level.corporators')));
        await settle(t);
        expect(api.escalations, ['corporators/en']);
        expect(find.byKey(const Key('escalate.message')), findsOneWidget);
        expect(find.textContaining('escalate.target'), findsNothing);
        expect(find.byKey(const Key('escalate.copy')), findsOneWidget);
        expect(find.byKey(const Key('escalate.share')), findsOneWidget);
        await t.tap(find.byKey(const Key('escalate.copy')));
        await settle(t);
        expect(launcher.calls, ['copy']);
      },
    );

    testWidgets(
      'a week after the corporators step on an overdue issue → zone office suggested; targets shown',
      (t) async {
        final api =
            FakeIssueActionsApi(
                issue: sampleIssue(
                  status: 'sent',
                  overdue: true,
                  actions: const ViewerActions(escalate: true),
                ),
                events: [
                  ev(
                    'x',
                    'escalated',
                    level: 'corporators',
                    at: DateTime.now().subtract(const Duration(days: 8)),
                  ),
                ],
              )
              ..draft = const EscalationDraft(
                level: 'zone_office',
                recommendedLevel: 'zone_office',
                subject: 'S',
                message: 'M',
                evidenceUrl: 'u',
                independenceNote: 'n',
                targets: [
                  EscalationTarget(
                    kind: 'phone',
                    label: 'Ward office',
                    phone: '07900000001',
                  ),
                  EscalationTarget(
                    kind: 'email',
                    label: 'Zone office',
                    email: 'z@example.org',
                  ),
                ],
              );
        final launcher = FakeLauncher();
        await pumpIssueRoutes(
          t,
          initial: _escalate,
          api: api,
          launcher: launcher,
        );
        await settle(t);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('escalate.level.zone_office')),
            matching: find.byKey(const Key('escalate.suggested')),
          ),
          findsOneWidget,
        );
        await t.tap(find.byKey(const ValueKey('escalate.level.zone_office')));
        await settle(t);
        await t.tap(find.text('Call Ward office'));
        await t.tap(find.text('Email Zone office'));
        await settle(t);
        expect(launcher.calls, ['call:07900000001', 'email:z@example.org']);
      },
    );
  });

  group('W-06-04 AMC closed it', () {
    for (final lang in ['en', 'gu']) {
      testWidgets('banner shows the reopen deadline ($lang)', (t) async {
        final deadline = DateTime.utc(2026, 10, 5, 9, 30);
        final api = FakeIssueActionsApi(
          issue: sampleIssue(
            status: 'sent',
            ccrsDeadline: deadline,
            actions: const ViewerActions(),
          ),
        );
        await pumpIssueRoutes(
          t,
          initial: '/issues/$kIssueId',
          api: api,
          locale: Locale(lang),
        );
        await settle(t);
        final time = Formatters.dateTime(deadline, lang);
        expect(find.byKey(const Key('ccrsClosed.banner')), findsOneWidget);
        expect(find.textContaining(time), findsOneWidget);
        expect(find.byKey(const Key('ccrsClosed.openSite')), findsOneWidget);
      });
    }

    testWidgets('sheet: "Yes, AMC closed it" records the close', (t) async {
      final api = FakeIssueActionsApi(
        issue: sampleIssue(
          status: 'sent',
          actions: const ViewerActions(ccrsClosed: true),
        ),
      );
      await pumpIssueRoutes(t, initial: '/issues/$kIssueId', api: api);
      await settle(t);
      await t.tap(find.byKey(const Key('lifecycle.ccrsClosed')));
      await settle(t);
      expect(find.text('Did AMC close your complaint?'), findsWidgets);
      await t.tap(find.byKey(const Key('ccrsClosed.yes')));
      await settle(t);
      expect(api.ccrsCalls, 1);
    });
  });

  group('W-06-05 IssueStatusActions', () {
    testWidgets('renders only what the role allows', (t) async {
      final api = FakeIssueActionsApi(
        issue: sampleIssue(
          status: 'acknowledged',
          actions: const ViewerActions(
            start: true,
            markFixed: true,
            reject: true,
          ),
        ),
      );
      await pumpIssueRoutes(t, initial: '/issues/$kIssueId', api: api);
      await settle(t);
      expect(
        find.byKey(const ValueKey('issueActions.in_progress')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('issueActions.marked_fixed')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('issueActions.rejected')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('issueActions.acknowledged')),
        findsNothing,
      );
    });

    testWidgets('a plain citizen sees no staff buttons', (t) async {
      final api = FakeIssueActionsApi(
        issue: sampleIssue(
          status: 'acknowledged',
          actions: const ViewerActions(),
        ),
      );
      await pumpIssueRoutes(t, initial: '/issues/$kIssueId', api: api);
      await settle(t);
      expect(
        find.byKey(const ValueKey('issueActions.in_progress')),
        findsNothing,
      );
    });

    testWidgets(
      'Start work sends expectedStatus; STALE_STATUS shows the message and Reload',
      (t) async {
        final api = FakeIssueActionsApi(
          issue: sampleIssue(
            status: 'acknowledged',
            actions: const ViewerActions(start: true),
          ),
        )..statusError = const AppError(code: 'STALE_STATUS');
        await pumpIssueRoutes(t, initial: '/issues/$kIssueId', api: api);
        await settle(t);
        await t.tap(find.byKey(const ValueKey('issueActions.in_progress')));
        await settle(t);
        expect(
          api.statusCalls.single,
          containsPair('expectedStatus', 'acknowledged'),
        );
        expect(api.statusCalls.single, containsPair('to', 'in_progress'));
        expect(
          find.text('This issue changed while you were here.'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('issueActions.reload')), findsOneWidget);
        await t.tap(find.byKey(const ValueKey('issueActions.in_progress')));
        await settle(t);
        expect(
          api.statusCalls[1]['clientActionId'],
          api.statusCalls[0]['clientActionId'],
          reason: 'retry keeps the idempotency key',
        );
      },
    );
  });

  testWidgets(
    'mark fixed: after photo uploaded with purpose after, then marked_fixed with its id',
    (t) async {
      final api = FakeIssueActionsApi(
        issue: sampleIssue(
          status: 'in_progress',
          actions: const ViewerActions(markFixed: true),
        ),
      );
      await pumpIssueRoutes(
        t,
        initial: '/issues/$kIssueId/mark-fixed',
        api: api,
      );
      await settle(t);
      await t.tap(find.byKey(const Key('markFixed.addPhoto')));
      await settle(t);
      await t.enterText(find.byKey(const Key('markFixed.note')), 'Patched');
      await t.tap(find.byKey(const Key('markFixed.submit')));
      await settle(t);
      expect(api.uploads, ['after']);
      expect(api.statusCalls.single, containsPair('to', 'marked_fixed'));
      expect(api.statusCalls.single['photoIds'], ['photo-1']);
      expect(
        api.statusCalls.single,
        containsPair('expectedStatus', 'in_progress'),
      );
    },
  );
}
