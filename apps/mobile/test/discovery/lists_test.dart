// W-07-02 /issues filters, sort, infinite scroll, empty + clear filters;
// W-07-06 My reports / Following incl. signed out; new items rise on refresh.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/settings/locale_controller.dart';
import 'package:saarthee/features/discovery/application/issue_list_controller.dart';
import 'package:saarthee/features/discovery/data/discovery_api.dart';
import 'package:saarthee/features/discovery/presentation/issue_list_screens.dart';

import 'fakes.dart';
import 'harness.dart';

List<Map<String, dynamic>> page(int from, int n) => [
  for (var i = from; i < from + n; i++) cardJson('i$i', daysAgo: i),
];

void main() {
  testWidgets('W-07-02 infinite scroll to "That\'s all."', (t) async {
    final api = FakeDiscoveryApi(pages: [page(0, 6), page(6, 6), page(12, 3)]);
    await pumpDiscovery(
      t,
      home: const IssuesScreen(wardId: 'w1'),
      api: api,
    );
    await settle(t);
    expect(find.byKey(const Key('issueCard.i0')), findsOneWidget);
    for (var i = 0; i < 12; i++) {
      await t.drag(find.byKey(const Key('issueList')), const Offset(0, -600));
      await settle(t, 2);
      if (find.byKey(const Key('issueList.end')).evaluate().isNotEmpty) break;
    }
    expect(find.byKey(const Key('issueList.end')), findsOneWidget);
    expect(api.calls.where((c) => c.startsWith('list')).length, 3);
    expect(api.queries.first.wardId, 'w1');
  });

  testWidgets('W-07-02 status chip and sort change the query; empty → '
      'Clear filters', (t) async {
    final api = FakeDiscoveryApi();
    await pumpDiscovery(t, home: const IssuesScreen(), api: api);
    await settle(t);
    await t.tap(find.byKey(const Key('issues.filter.overdue')));
    await settle(t);
    expect(api.queries.last.statuses, {'overdue'});
    expect(api.queries.last.toQuery('en')['status'], 'overdue');
    expect(find.byKey(const Key('issues.empty')), findsOneWidget);
    await t.tap(find.text('Clear filters'));
    await settle(t);
    expect(api.queries.last.statuses, isEmpty);
    await t.tap(find.byKey(const Key('issues.sort')));
    await settle(t);
    await t.tap(find.byKey(const Key('issues.sort.most_affected')));
    await settle(t);
    expect(api.queries.last.sort, 'most_affected');
  });

  testWidgets('W-07-02 category sheet (multi) narrows the list', (t) async {
    final api = FakeDiscoveryApi();
    await pumpDiscovery(t, home: const IssuesScreen(), api: api);
    await settle(t);
    await t.tap(find.byKey(const Key('issues.filter.category')));
    await settle(t);
    await t.tap(find.byKey(const Key('categorySheet.garbage')));
    await t.tap(find.byKey(const Key('categorySheet.water')));
    await t.pump();
    await t.tap(find.byKey(const Key('categorySheet.done')));
    await settle(t);
    expect(api.queries.last.categories, {'garbage', 'water'});
  });

  testWidgets('only items new since the last refresh are marked to rise', (
    t,
  ) async {
    final api = FakeDiscoveryApi(pages: [page(0, 2)]);
    final h = await pumpDiscovery(t, home: const IssuesScreen(), api: api);
    await settle(t);
    api.pages = [
      [cardJson('new'), ...page(0, 2)],
    ];
    const q = IssueQuery();
    await h.container.read(issueListProvider(q).notifier).refresh();
    expect(h.container.read(issueListProvider(q)).newIds, {'new'});
  });

  testWidgets('W-07-06 My reports: pending tag; signed out → sign-in prompt', (
    t,
  ) async {
    final api = FakeDiscoveryApi(
      pages: [
        [cardJson('m1'), cardJson('m2', pendingReview: true), cardJson('m3')],
      ],
    );
    await pumpDiscovery(t, home: const MyReportsScreen(), api: api);
    await settle(t);
    expect(find.byKey(const Key('tag.pendingReview')), findsOneWidget);
    expect(api.queries.single.mine, isTrue);
  });

  testWidgets('W-07-06 signed out → "Sign in to see your reports"', (t) async {
    await pumpDiscovery(
      t,
      home: const MyReportsScreen(),
      api: FakeDiscoveryApi(),
      signedIn: false,
    );
    await settle(t);
    expect(find.text('Sign in to see your reports'), findsOneWidget);
  });

  testWidgets('W-07-06 Following: Unfollow removes the item; empty copy', (
    t,
  ) async {
    final api = FakeDiscoveryApi(
      pages: [
        [cardJson('f1'), cardJson('f2')],
      ],
    );
    await pumpDiscovery(t, home: const FollowingScreen(), api: api);
    await settle(t);
    await t.tap(find.byKey(const Key('following.unfollow.f1')));
    await settle(t);
    expect(find.byKey(const Key('issueCard.f1')), findsNothing);
    expect(api.calls, contains('follow f1 false'));
    expect(api.queries.first.following, isTrue);
  });

  testWidgets('W-07-06 Following empty', (t) async {
    await pumpDiscovery(
      t,
      home: const FollowingScreen(),
      api: FakeDiscoveryApi(),
    );
    await settle(t);
    expect(find.byKey(const Key('following.empty')), findsOneWidget);
  });

  testWidgets('loading skeleton while the first page is on its way', (t) async {
    final api = FakeDiscoveryApi()..listGate = Completer<void>();
    await pumpDiscovery(t, home: const IssuesScreen(), api: api);
    await t.pump();
    expect(find.byKey(const Key('issueList.loading')), findsOneWidget);
    api.listGate!.complete();
    await settle(t);
    expect(find.byKey(const Key('issues.empty')), findsOneWidget);
  });

  testWidgets(
    'switching the app language refetches the list in that language',
    (t) async {
      final api = FakeDiscoveryApi(pages: [page(0, 3)]);
      await pumpDiscovery(
        t,
        home: const IssuesScreen(wardId: 'w1'),
        api: api,
      );
      await settle(t);
      expect(api.listLangs, ['en']);
      final container = ProviderScope.containerOf(
        t.element(find.byType(IssuesScreen)),
      );
      await container.read(localeProvider.notifier).setLanguage('gu');
      await settle(t);
      expect(api.listLangs.last, 'gu');
      expect(find.byKey(const Key('issueCard.i0')), findsOneWidget);
    },
  );
}
