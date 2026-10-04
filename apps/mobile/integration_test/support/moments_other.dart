// MO-20 … MO-25 (TASK-08 alerts/inbox, TASK-09 My Ward, TASK-09/11
// scorecard + ward dashboard, TASK-12 RSVP, TASK-10 staff console).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/features/alerts/application/in_app_alert_controller.dart';
import 'package:saarthee/features/alerts/data/alert_models.dart';
import 'package:saarthee/features/staff/ward_dashboard/rep_console_api.dart';
import 'package:saarthee/features/staff/ward_dashboard/ward_dashboard_screen.dart';
import 'package:saarthee/features/ward/data/ward_api.dart';
import 'package:saarthee/router/app_router.dart';

import '../../test/alerts/alert_fakes.dart';
import '../../test/helpers/fake_wards.dart';
import '../../test/helpers/motion.dart';
import '../../test/staff/rep_console_fakes.dart';
import '../../test/staff/staff_harness.dart';
import 'motion_moment.dart';
import 'perf_app.dart';

WardScorecard _card() => WardScorecard.fromJson({
  'wardId': paldi.id,
  'hidden': false,
  'windowDays': 90,
  'refreshedAt': '2026-10-04T04:30:00.000Z',
  'metrics': {
    'issuesReported': 120,
    'medianDaysAck': 2,
    'medianDaysFix': 5.5,
    'verifiedPct': 75,
    'reopenPct': 16.7,
    'openBacklog': 38,
    'reportsPer1000': 2.4,
  },
  'population': {'value': 50000, 'sourceNote': 'Census'},
});

final otherMoments = <MotionMoment>[
  MotionMoment('MO-20', 'New alert banner + critical pulse', (t) async {
    final c = await pumpPerfApp(t, PerfFakes());
    await frames(t, ms1200);
    return () async {
      c
          .read(inAppAlertProvider.notifier)
          .offer(Alert.fromJson(alertJson(id: 'crit', severity: 'critical')));
      await frames(t, const Duration(milliseconds: 2500));
    };
  }),
  MotionMoment('MO-21', 'Inbox swipe to read + badge roll', (t) async {
    final fakes = PerfFakes();
    fakes.alerts.inboxItems = [
      inboxJson('n1'),
      inboxJson('n2', kind: 'issue_update'),
    ];
    final c = await pumpPerfApp(t, fakes);
    await frames(t, ms600);
    unawaited(c.read(appRouterProvider).push('/me/notifications'));
    await waitForWidget(t, find.byKey(const ValueKey('inboxRow.n1')));
    await frames(t, ms1200);
    return () async {
      await t.drag(
        find.byKey(const ValueKey('inboxRow.n1')),
        const Offset(-300, 0),
      );
      await frames(t, ms1200);
    };
  }),
  MotionMoment('MO-22', 'My Ward rows stagger + "Message sent" toast', (
    t,
  ) async {
    final c = await pumpPerfApp(t, PerfFakes());
    await frames(t, ms1200);
    return () async {
      await t.tap(find.byKey(const Key('nav.4')));
      await frames(t, ms1200);
      final router = c.read(appRouterProvider);
      unawaited(router.push('/representatives/c0'));
      await frames(t, ms600);
      unawaited(router.push('/representatives/c0/message'));
      await waitForWidget(t, find.byKey(const Key('relay.subject')));
      await t.enterText(find.byKey(const Key('relay.subject')), 'Streetlight');
      await t.enterText(find.byKey(const Key('relay.body')), 'Light is off.');
      await tapKey(t, const Key('relay.send'));
      await frames(t, const Duration(milliseconds: 2000));
    };
  }),
  MotionMoment('MO-23', 'Scorecard count-up + bars', (t) async {
    final fakes = PerfFakes()..ward.card = _card();
    final c = await pumpPerfApp(t, fakes);
    await frames(t, ms1200);
    return () async {
      unawaited(c.read(appRouterProvider).push('/ward/${paldi.id}/scorecard'));
      await frames(t, const Duration(milliseconds: 2000));
    };
  }),
  MotionMoment('MO-23-dashboard', 'Ward dashboard count-up + bars', (t) async {
    final fake = FakeRepConsoleApi();
    return () async {
      await pumpMotion(
        t,
        const WardDashboardScreen(),
        overrides: [repConsoleApiProvider.overrideWithValue(fake)],
      );
      await frames(t, const Duration(milliseconds: 2000));
    };
  }),
  MotionMoment('MO-24', 'Initiative RSVP morph + attendee roll', (t) async {
    final c = await pumpPerfApp(t, PerfFakes());
    await frames(t, ms600);
    unawaited(c.read(appRouterProvider).push('/initiatives/i1'));
    await waitForWidget(
      t,
      find.byKey(const Key('rsvp.button'), skipOffstage: false),
    );
    await t.ensureVisible(
      find.byKey(const Key('rsvp.button'), skipOffstage: false),
    );
    await frames(t, ms600);
    return () async {
      await t.tap(find.byKey(const Key('rsvp.button')));
      await frames(t, const Duration(milliseconds: 1500));
    };
  }),
  MotionMoment('MO-25', 'Staff console fades (in-app)', (t) async {
    final r = await pumpStaff(t, location: '/staff');
    t.view.reset(); // phone size: in-app staff screens on the device
    await frames(t, ms1200);
    return () async {
      for (final route in ['/staff/moderation', '/staff', '/staff/alerts']) {
        r.router.go(route);
        await frames(t, ms600);
      }
    };
  }),
];
