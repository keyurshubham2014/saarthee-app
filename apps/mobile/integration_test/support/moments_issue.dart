// MO-14 … MO-19 (TASK-06 lifecycle, TASK-07 feed / detail / map).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/features/issue_actions/application/issue_providers.dart';

import '../../test/issue_actions/fakes.dart';
import 'motion_moment.dart';
import 'perf_app.dart';

/// App on the TASK-06 sample issue's detail.
Future<(ProviderContainer, PerfFakes)> _onIssue(
  WidgetTester t,
  PerfFakes fakes,
) async {
  final c = await pumpPerfApp(t, fakes);
  await frames(t, ms600);
  goTo(c, '/issues/$kIssueId');
  await waitForWidget(t, find.byKey(const Key('lifecycle.verify')));
  await frames(t, ms1200);
  return (c, fakes);
}

final issueMoments = <MotionMoment>[
  MotionMoment('MO-14', 'Status chip cross-fade + timeline expand', (t) async {
    final fakes = PerfFakes();
    fakes.issueActions.issue = sampleIssue(status: 'in_progress');
    final c = await pumpPerfApp(t, fakes);
    await frames(t, ms600);
    goTo(c, '/issues/$kIssueId');
    await waitForWidget(t, find.byKey(const ValueKey('statusChip.inProgress')));
    await frames(t, ms1200);
    return () async {
      // A status push while the detail is open refreshes both providers.
      fakes.issueActions
        ..issue = sampleIssue()
        ..eventList = [
          ...fakes.issueActions.eventList,
          ev('e2', 'status_change', to: 'marked_fixed', actor: 'staff'),
        ];
      c
        ..invalidate(issueLifecycleProvider(kIssueId))
        ..invalidate(issueEventsProvider(kIssueId));
      await frames(t, const Duration(milliseconds: 1500));
    };
  }),
  MotionMoment('MO-15', 'Verify fix: progress → toast check → Verified', (
    t,
  ) async {
    await _onIssue(t, PerfFakes());
    await tapKey(t, const Key('lifecycle.verify'));
    await waitForWidget(t, find.byKey(const Key('verify.yes')));
    await t.tap(find.byKey(const Key('verify.yes')));
    await waitForWidget(t, find.byKey(const Key('verify.take')));
    await t.tap(find.byKey(const Key('verify.take')));
    await waitForWidget(t, find.textContaining('from the problem'));
    await frames(t, ms600);
    return () async {
      await tapKey(t, const Key('issueActions.send'));
      await frames(t, const Duration(milliseconds: 2500));
    };
  }),
  MotionMoment('MO-16', 'Feed card → detail Hero + stagger', (t) async {
    await pumpPerfApp(t, PerfFakes());
    await frames(t, ms1200);
    await t.ensureVisible(find.byKey(const Key('issueCard.i0')));
    await frames(t, ms300);
    return () async {
      await t.tap(find.byKey(const Key('issueCard.i0')));
      await frames(t, const Duration(milliseconds: 1500));
    };
  }),
  MotionMoment('MO-17', '"Me too" spring + rolling count', (t) async {
    final c = await pumpPerfApp(t, PerfFakes());
    await frames(t, ms600);
    goTo(c, '/issues/i0');
    await waitForWidget(t, find.byKey(const Key('detail.meToo.icon')));
    await t.ensureVisible(find.byKey(const Key('detail.meToo.icon')));
    await frames(t, ms1200);
    return () async {
      await t.tap(find.byKey(const Key('detail.meToo.icon')));
      await frames(t, ms1200);
    };
  }),
  MotionMoment('MO-18', 'Pull to refresh indicator', (t) async {
    await pumpPerfApp(t, PerfFakes());
    await frames(t, ms1200);
    return () async {
      // Fling down from the upper body (above the first feed card).
      await t.flingFrom(const Offset(180, 260), const Offset(0, 400), 1500);
      await frames(t, const Duration(milliseconds: 2000));
    };
  }),
  MotionMoment('MO-19', 'Map pins drop, cluster zoom, preview sheet', (
    t,
  ) async {
    await pumpPerfApp(t, PerfFakes());
    await frames(t, ms1200);
    return () async {
      await t.tap(find.byKey(const Key('nav.1')));
      await frames(t, ms1200);
      await t.tap(find.bySemanticsLabel(RegExp('issues here')).first);
      await frames(t, ms1200);
      // Any pin still on screen after the zoom opens the preview sheet.
      await t.tap(
        find.byWidgetPredicate((w) => '${w.key}'.contains("'map.pin.")).first,
      );
      await frames(t, ms1200);
    };
  }),
];
