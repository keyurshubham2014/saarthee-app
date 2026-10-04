// MO-01 … MO-08 (TASK-03 shell motion, TASK-07 Home).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/router/app_router.dart';

import 'motion_moment.dart';
import 'perf_app.dart';

final shellMoments = <MotionMoment>[
  MotionMoment('MO-01', 'App launch', (t) async {
    final fakes = PerfFakes();
    return () async {
      await pumpPerfApp(t, fakes, showLaunch: true);
      await frames(t, const Duration(milliseconds: 1500));
    };
  }),
  MotionMoment('MO-02', 'Onboarding shared axis + language tile', (t) async {
    await pumpPerfApp(t, PerfFakes(), onboarded: false);
    await waitForWidget(t, find.byKey(const Key('onboarding.language.gu')));
    await frames(t, ms600);
    return () async {
      await t.tap(find.byKey(const Key('onboarding.language.gu')));
      await frames(t, ms600);
      await tapKey(t, const Key('onboarding.language.continue'));
      await frames(t, ms600);
      await tapKey(t, const Key('onboarding.intro.continue'));
      await frames(t, ms600);
    };
  }),
  MotionMoment('MO-03', 'Tab switch fade-through + nav pill', (t) async {
    await pumpPerfApp(t, PerfFakes());
    await frames(t, ms1200);
    return () async {
      for (final i in [1, 3, 4, 0]) {
        await t.tap(find.byKey(Key('nav.$i')));
        await frames(t, ms600);
      }
    };
  }),
  MotionMoment('MO-04', 'Push navigation + ward picker sheet', (t) async {
    final c = await pumpPerfApp(t, PerfFakes());
    await frames(t, ms1200);
    return () async {
      unawaited(c.read(appRouterProvider).push('/me/settings'));
      await frames(t, ms600);
      c.read(appRouterProvider).pop();
      await frames(t, ms600);
      await t.tap(find.byKey(const Key('homeHeader.ward')));
      await frames(t, ms600);
    };
  }),
  MotionMoment('MO-05', 'Press scale (Report card, issue card)', (t) async {
    await pumpPerfApp(t, PerfFakes());
    await frames(t, ms1200);
    Future<void> pressHold(Finder f) async {
      final g = await t.startGesture(t.getCenter(f));
      await frames(t, ms300);
      // Slide off before release so the tap does not navigate.
      await g.moveBy(const Offset(0, 80));
      await g.up();
      await frames(t, ms300);
    }

    return () async {
      await pressHold(find.byKey(const Key('reportCard')));
      // The first feed card is on screen on a phone; scroll only if not.
      await t.ensureVisible(find.byKey(const Key('issueCard.i0')));
      await frames(t, ms300);
      await pressHold(find.byKey(const Key('issueCard.i0')));
    };
  }),
  MotionMoment('MO-06', 'Skeleton shimmer → content (1 s fixture)', (t) async {
    final fakes = PerfFakes();
    await pumpPerfApp(t, fakes);
    await frames(t, ms1200);
    await t.ensureVisible(find.byKey(const Key('home.seeAll')));
    await frames(t, ms300);
    final gate = Completer<void>();
    fakes.discovery.listGate = gate;
    return () async {
      await t.tap(find.byKey(const Key('home.seeAll')));
      await frames(t, const Duration(seconds: 1));
      gate.complete();
      await frames(t, ms1200);
    };
  }),
  MotionMoment('MO-07', 'Home first load stagger', (t) async {
    final fakes = PerfFakes();
    return () async {
      await pumpPerfApp(t, fakes);
      await frames(t, const Duration(milliseconds: 1500));
    };
  }),
  MotionMoment('MO-08', 'Report card spring + first-launch ring', (t) async {
    final fakes = PerfFakes();
    return () async {
      await pumpPerfApp(t, fakes, firstLaunch: true);
      await frames(t, const Duration(milliseconds: 3000));
    };
  }),
];
