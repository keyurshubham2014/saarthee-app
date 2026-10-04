// W-11-03 claims review, W-11-05 ward issue actions, W-11-06 messages inbox.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/features/staff/claims/staff_claim_detail_screen.dart';
import 'package:saarthee/features/staff/messages/rep_messages_screen.dart';
import 'package:saarthee/features/staff/shell/staff_session.dart';
import 'package:saarthee/features/staff/ward_dashboard/rep_console_api.dart';
import 'package:saarthee/features/staff/ward_dashboard/ward_issues_screen.dart';

import '../helpers/motion.dart';
import 'rep_console_fakes.dart';

StaffMe me(String role) => StaffMe(
  actorId: 'u1',
  actorKind: 'user',
  role: role,
  displayName: null,
  wardIds: const [],
  nav: const [],
);

final claimJson = {
  'claimId': 'c1',
  'status': 'pending',
  'phoneMatch': true,
  'evidenceCount': 1,
  'createdAt': '2026-10-03T05:30:00Z',
  'representative': {
    'id': 'r1',
    'nameEn': 'Sample Corporator 30-A',
    'nameGu': 'નમૂના',
    'role': 'corporator',
  },
  'claimant': {'displayName': 'Sample Citizen', 'ward': null},
  'evidence': [
    {'photoId': 'p1'},
  ],
  'claimantNote': null,
  'otpVerified': true,
  'representativeRecord': {
    'id': 'r1',
    'nameEn': 'Sample Corporator 30-A',
    'nameGu': 'નમૂના',
    'termStart': '2026-03-01',
    'termEnd': '2031-02-28',
    'sourceUrl': 'https://example.org',
    'verified': false,
  },
};

Future<FakeRepConsoleApi> pump(
  WidgetTester t,
  Widget w, {
  String role = 'admin',
}) async {
  t.view.physicalSize = const Size(1200, 3000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final api = FakeRepConsoleApi()..claimById['c1'] = claimJson;
  await pumpMotion(
    t,
    w,
    reduced: true,
    overrides: [
      repConsoleApiProvider.overrideWithValue(api),
      staffMeProvider.overrideWith((ref) async => me(role)),
    ],
  );
  await t.pump();
  await t.pump();
  return api;
}

void main() {
  testWidgets('W-11-03 approve needs a method; reject needs 5–300 characters', (
    t,
  ) async {
    final api = await pump(t, const StaffClaimDetailScreen(id: 'c1'));
    expect(find.byKey(const Key('phoneMatch.true')), findsOneWidget);
    await t.tap(find.byKey(const Key('claim.approve')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('claim.approve.confirm')));
    await t.pump();
    expect(find.text('Choose a method.'), findsOneWidget);
    await t.tap(find.byKey(const Key('claim.method')));
    await t.pumpAndSettle();
    await t.tap(find.text('Certificate of election').last);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('claim.approve.confirm')));
    await t.pumpAndSettle();
    expect(api.calls, contains('approve:c1:certificate_of_election'));

    await t.tap(find.byKey(const Key('claim.reject')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('claim.reason')), 'abc');
    await t.tap(find.byKey(const Key('claim.reason.confirm')));
    await t.pump();
    expect(find.text('Give a reason of 5 to 300 characters.'), findsOneWidget);
    await t.enterText(
      find.byKey(const Key('claim.reason')),
      'Document unreadable',
    );
    await t.tap(find.byKey(const Key('claim.reason.confirm')));
    await t.pumpAndSettle();
    expect(api.calls, contains('reject:c1:Document unreadable'));
  });

  testWidgets('W-11-03 moderator sees the claim read-only', (t) async {
    await pump(t, const StaffClaimDetailScreen(id: 'c1'), role: 'moderator');
    expect(find.byKey(const Key('claim.readOnly')), findsOneWidget);
    expect(find.byKey(const Key('claim.approve')), findsNothing);
    expect(find.byKey(const Key('claim.reject')), findsNothing);
  });

  testWidgets('W-11-05 action sheet shows only allowedActions', (t) async {
    final api = FakeRepConsoleApi()
      ..issuesJson = {
        'items': [
          {
            'id': 'i1',
            'title': 'Pothole',
            'status': 'in_progress',
            'overdue': true,
            'category': {'slug': 'roads'},
            'allowedActions': ['mark_fixed', 'comment'],
          },
        ],
        'electionMode': {'active': true},
      };
    t.view.physicalSize = const Size(1200, 3000);
    addTearDown(t.view.reset);
    await pumpMotion(
      t,
      const WardIssuesScreen(),
      reduced: true,
      overrides: [repConsoleApiProvider.overrideWithValue(api)],
    );
    await t.pump();
    await t.pump();
    await t.tap(find.byKey(const Key('wardIssues.row.i1')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('wardIssue.act.acknowledge')), findsNothing);
    expect(find.byKey(const Key('wardIssue.act.mark_fixed')), findsOneWidget);
    expect(
      find.text('Comments are paused while election mode is on.'),
      findsOneWidget,
    );
    for (final never in ['verify', 'reject', 'merge', 'hide']) {
      expect(find.byKey(Key('wardIssue.act.$never')), findsNothing);
    }
    await t.tap(find.byKey(const Key('wardIssue.act.mark_fixed')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('wardIssue.send')));
    await t.pumpAndSettle();
    expect(api.calls, contains('status:i1:marked_fixed'));
  });

  FakeRepConsoleApi msgApi() => FakeRepConsoleApi()
    ..messagesJson = {
      'items': [
        {
          'id': 'm1',
          'subject': 'Drain',
          'status': 'sent',
          'readByRepAt': null,
          'citizenLabel': {'en': 'A resident of ward 30 Paldi', 'gu': 'x'},
        },
        {
          'id': 'm2',
          'subject': 'Light',
          'status': 'replied',
          'readByRepAt': '2026-10-01T00:00:00Z',
          'citizenLabel': {'en': 'A resident', 'gu': 'x'},
        },
      ],
      'unread': 1,
    }
    ..messageById['m2'] = {
      'id': 'm2',
      'subject': 'Light',
      'body': 'Streetlight out',
      'status': 'replied',
      'repliedAt': '2026-10-02T00:00:00Z',
      'replyChannel': 'email',
      'reply': 'Done',
      'citizenLabel': {'en': 'A resident', 'gu': 'x'},
    }
    ..messageById['m1'] = {
      'id': 'm1',
      'subject': 'Drain',
      'body': 'Overflow',
      'status': 'sent',
      'repliedAt': null,
      'citizenLabel': {'en': 'A resident', 'gu': 'x'},
    };

  Future<void> pumpMsg(WidgetTester t, Widget w) async {
    await pumpMotion(
      t,
      w,
      reduced: true,
      overrides: [repConsoleApiProvider.overrideWithValue(msgApi())],
    );
    await t.pump();
    await t.pump();
  }

  testWidgets('W-11-06 inbox shows the unread dot and the resident label', (
    t,
  ) async {
    await pumpMsg(t, const RepMessagesScreen());
    expect(find.byKey(const Key('repMsg.unread.m1')), findsOneWidget);
    expect(find.byKey(const Key('repMsg.unread.m2')), findsNothing);
    expect(find.text('A resident of ward 30 Paldi'), findsOneWidget);
  });

  testWidgets('W-11-06 replied message shows "Replied by email on"', (t) async {
    await pumpMsg(t, const RepMessageDetailScreen(id: 'm2'));
    expect(find.textContaining('Replied by email on'), findsOneWidget);
  });

  testWidgets('W-11-06 reply field is limited to 2,000 characters', (t) async {
    await pumpMsg(t, const RepMessageDetailScreen(id: 'm1'));
    expect(
      t.widget<TextField>(find.byKey(const Key('repMsg.replyField'))).maxLength,
      2000,
    );
  });
}
