// MO-09 … MO-13 (TASK-05 report flow) with the fake camera / GPS and the
// scriptable report API.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/features/report/data/report_models.dart';

import 'motion_moment.dart';
import 'perf_app.dart';

const _roads = ValueKey('report.tile.roads');

/// App on `/report` step 1, tiles shown.
Future<(ProviderContainer, PerfFakes)> _onStep1(
  WidgetTester t, {
  bool autoPhoto = true,
  List<NearbyIssue> nearby = const [],
}) async {
  final fakes = PerfFakes();
  fakes.capture.autoPhoto = autoPhoto;
  fakes.report.nearbyItems = nearby;
  final c = await pumpPerfApp(t, fakes);
  await frames(t, ms600);
  goTo(c, '/report');
  await waitForWidget(t, find.byKey(_roads));
  await frames(t, ms1200);
  return (c, fakes);
}

/// Tile → camera (fake) → blur + upload done.
Future<void> _photoTaken(WidgetTester t, PerfFakes fakes) async {
  await t.tap(find.byKey(_roads));
  await waitUntil(t, () => fakes.report.uploads.isNotEmpty);
  await frames(t, ms1200);
}

NearbyIssue _dup() => NearbyIssue(
  id: 'dup-1',
  categorySlug: 'roads',
  status: 'reported',
  distanceM: 30,
  meTooCount: 2,
  createdAt: DateTime(2026, 9, 24),
  wardNameEn: 'Paldi',
  wardNameGu: 'પાલડી',
);

final reportMoments = <MotionMoment>[
  MotionMoment('MO-09', 'Report step 1 tile pop + selection', (t) async {
    final fakes = PerfFakes()..capture.autoPhoto = false;
    final c = await pumpPerfApp(t, fakes);
    await frames(t, ms600);
    return () async {
      goTo(c, '/report');
      await frames(t, ms1200);
      await t.tap(find.byKey(_roads));
      await frames(t, ms600);
    };
  }),
  MotionMoment('MO-10', 'Between report steps + progress bar', (t) async {
    final (_, fakes) = await _onStep1(t);
    return () async {
      await _photoTaken(t, fakes);
      await tapKey(t, const Key('report.continue'));
      await frames(t, ms600);
      await t.tap(find.byTooltip('Back').first);
      await frames(t, ms600);
    };
  }),
  MotionMoment('MO-11', 'Photo fly-in + pin drop', (t) async {
    final (_, fakes) = await _onStep1(t);
    return () => _photoTaken(t, fakes);
  }),
  MotionMoment('MO-12', 'Duplicate card slide + "Added ✓" morph', (t) async {
    final (_, fakes) = await _onStep1(t, nearby: [_dup()]);
    await _photoTaken(t, fakes);
    const add = Key('report.dup.addMeToo');
    await waitForWidget(t, find.byKey(add, skipOffstage: false));
    await t.ensureVisible(find.byKey(add, skipOffstage: false));
    await frames(t, ms300);
    return () async {
      await t.tap(find.byKey(const Key('report.dup.addMeToo')));
      await frames(t, const Duration(milliseconds: 2000));
    };
  }),
  MotionMoment('MO-13', 'Report submitted (circle, check, number)', (t) async {
    final (_, fakes) = await _onStep1(t);
    await _photoTaken(t, fakes);
    await tapKey(t, const Key('report.continue'));
    await frames(t, ms1200);
    await t.ensureVisible(
      find.byKey(const Key('report.submit'), skipOffstage: false),
    );
    await frames(t, ms300);
    return () async {
      await t.tap(find.byKey(const Key('report.submit')));
      await frames(t, const Duration(milliseconds: 2500));
    };
  }),
];
