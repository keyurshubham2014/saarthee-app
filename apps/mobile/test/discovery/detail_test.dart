// W-07-03 detail states, W-07-04 optimistic Me too / Follow + rollback,
// W-07-09 Me too spring + rolling count + haptic, W-07-10 reduced motion.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/api/app_error.dart';
import 'package:saarthee/core/theme/motion.dart';
import 'package:saarthee/features/discovery/presentation/issue_detail_screen.dart';
import 'package:saarthee/features/discovery/presentation/share_issue.dart';
import 'package:saarthee/features/discovery/presentation/widgets/social_buttons.dart';

import '../helpers/fake_haptics.dart';
import 'fakes.dart';
import 'harness.dart';

const id = 'i-1';

Future<FakeDiscoveryApi> openDetail(
  WidgetTester t,
  Map<String, dynamic> body, {
  FakeSaartheeHaptics? haptics,
  bool reduced = false,
  bool disableAnimations = false,
  bool signedIn = true,
  List overrides = const [],
}) async {
  final api = FakeDiscoveryApi(details: {id: body}, unknownIsNotFound: true);
  await pumpDiscovery(
    t,
    home: const IssueDetailScreen(issueId: id),
    api: api,
    haptics: haptics,
    reduced: reduced ? true : null,
    disableAnimations: disableAnimations,
    signedIn: signedIn,
    overrides: overrides,
  );
  await settle(t);
  return api;
}

double iconScale(WidgetTester t) => t
    .widget<ScaleTransition>(find.byKey(const Key('detail.meToo.icon')))
    .scale
    .value;

void main() {
  testWidgets('W-07-03 neighbour view: title, reporter label, actions, '
      'before/after tabs', (t) async {
    await openDetail(t, detailJson(id, after: ['/x/after.jpg']));
    expect(find.byKey(const Key('detail.title')), findsOneWidget);
    expect(find.text('Reported by a resident of Paldi'), findsOneWidget);
    expect(find.byKey(const Key('detail.meToo')), findsOneWidget);
    expect(find.byKey(const Key('detail.follow')), findsOneWidget);
    expect(find.byKey(const Key('detail.share')), findsOneWidget);
    expect(find.byKey(const Key('detail.tab.after')), findsOneWidget);
    expect(find.byKey(const Key('detail.addCcrs')), findsNothing);
    // Hero tags exist on the detail photo and title.
    expect(
      find.byWidgetPredicate((w) => w is Hero && w.tag == 'issue-title-$id'),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate((w) => w is Hero && w.tag == 'issue-photo-$id'),
      findsOneWidget,
    );
  });

  testWidgets('W-07-03 reporter sees Add AMC complaint number, no Me too', (
    t,
  ) async {
    await openDetail(
      t,
      detailJson(id, isReporter: true, canMeToo: false, canLinkCcrs: true),
    );
    expect(find.byKey(const Key('detail.meToo')), findsNothing);
    expect(find.byKey(const Key('detail.addCcrs')), findsOneWidget);
  });

  testWidgets('W-07-03 merged banner, rejected reason, 404', (t) async {
    await openDetail(t, detailJson(id, status: 'merged', mergedIntoId: 'i-2'));
    expect(find.byKey(const Key('detail.merged')), findsOneWidget);
    expect(find.text('Open it'), findsOneWidget);
  });

  testWidgets('W-07-03 rejected shows the reason; unknown id → not available', (
    t,
  ) async {
    await openDetail(
      t,
      detailJson(id, status: 'rejected', rejectionReason: 'Duplicate'),
    );
    expect(find.text('Not accepted: Duplicate'), findsOneWidget);
  });

  testWidgets('W-07-03 404', (t) async {
    final api = FakeDiscoveryApi(unknownIsNotFound: true);
    await pumpDiscovery(
      t,
      home: const IssueDetailScreen(issueId: 'nope'),
      api: api,
    );
    await settle(t);
    expect(find.byKey(const Key('detail.notFound')), findsOneWidget);
  });

  testWidgets('W-07-09 Me too: icon springs to ~1.2, count rolls 12 → 13, '
      'one light haptic', (t) async {
    final haptics = FakeSaartheeHaptics();
    final api = await openDetail(t, detailJson(id), haptics: haptics);
    expect(find.text('12'), findsOneWidget);
    await t.tap(find.byKey(const Key('detail.meToo')));
    await t.pump();
    // Half way through springIn the icon is near its 1.2 peak.
    await t.pump(SaartheeMotion.springIn.duration ~/ 2);
    expect(iconScale(t), closeTo(MeTooButton.peakScale, 0.05));
    await t.pump(SaartheeMotion.short.duration);
    await settle(t, 2);
    expect(iconScale(t), 1);
    expect(find.text('13'), findsOneWidget);
    expect(haptics.calls, ['light']);
    expect(api.calls, contains('meToo $id true'));
    // Me too also follows.
    expect(find.text('Following'), findsOneWidget);
  });

  testWidgets('W-07-04 Me too failure rolls the count back with a snackbar', (
    t,
  ) async {
    final api = await openDetail(t, detailJson(id));
    api.meTooError = const AppError(code: 'RATE_LIMITED');
    await t.tap(find.byKey(const Key('detail.meToo')));
    await settle(t, 3);
    expect(find.text('12'), findsOneWidget);
    expect(find.text("Couldn't save that. Try again."), findsOneWidget);
  });

  testWidgets('W-07-04 Follow toggles optimistically', (t) async {
    final api = await openDetail(t, detailJson(id));
    await t.tap(find.byKey(const Key('detail.follow')));
    await settle(t, 2);
    expect(find.text('Following'), findsOneWidget);
    expect(api.calls, contains('follow $id true'));
    await t.tap(find.byKey(const Key('detail.follow')));
    await settle(t, 2);
    expect(find.text('Follow'), findsOneWidget);
  });

  testWidgets('Share sends the title, status and /i/<id> link, no reporter', (
    t,
  ) async {
    final shared = <String>[];
    await openDetail(
      t,
      detailJson(id),
      overrides: [
        issueSharerProvider.overrideWithValue((s) async => shared.add(s)),
      ],
    );
    await t.tap(find.byKey(const Key('detail.share')));
    await t.pump();
    expect(shared.single, contains('Pothole · Paldi — Reported'));
    expect(shared.single, contains('/i/$id'));
    expect(shared.single, isNot(contains('resident')));
  });

  for (final mode in ['system', 'in-app']) {
    testWidgets('W-07-10 reduced motion ($mode): Me too swaps at once', (
      t,
    ) async {
      await openDetail(
        t,
        detailJson(id),
        reduced: mode == 'in-app',
        disableAnimations: mode == 'system',
      );
      await t.tap(find.byKey(const Key('detail.meToo')));
      await t.pump();
      await t.pump();
      expect(iconScale(t), 1);
      expect(find.text('13'), findsOneWidget);
    });
  }
}
