// W-11-04 dashboard states, W-11-07 first-view motion, W-11-08 reduced motion.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/api/app_error.dart';
import 'package:saarthee/core/theme/motion.dart';
import 'package:saarthee/features/staff/ward_dashboard/rep_console_api.dart';
import 'package:saarthee/features/staff/ward_dashboard/ward_dashboard_providers.dart';
import 'package:saarthee/features/staff/ward_dashboard/ward_dashboard_screen.dart';

import '../helpers/motion.dart';
import 'rep_console_fakes.dart';

String tile(WidgetTester t, String k) => t
    .widget<Text>(
      find
          .descendant(
            of: find.byKey(Key('wardDash.tile.$k')),
            matching: find.byKey(const Key('scorecardTile.value')),
          )
          .last, // the newest body while a ward switch cross-fades
    )
    .data!;

double barScale(WidgetTester t, int i) => t
    .widget<Transform>(
      find
          .descendant(
            of: find.byKey(Key('wardDash.trendBar.$i')),
            matching: find.byKey(const Key('scorecardBar.fill')),
          )
          .last,
    )
    .transform
    .storage[5];

Future<(ProviderContainer, FakeRepConsoleApi)> pumpDash(
  WidgetTester t, {
  bool? reduced,
  bool disableAnimations = false,
  FakeRepConsoleApi? api,
}) async {
  t.view.physicalSize = const Size(1200, 5000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final fake = api ?? FakeRepConsoleApi();
  final c = await pumpMotion(
    t,
    const WardDashboardScreen(),
    reduced: reduced,
    disableAnimations: disableAnimations,
    overrides: [repConsoleApiProvider.overrideWithValue(fake)],
  );
  await t.pump();
  await t.pump();
  return (c, fake);
}

void main() {
  testWidgets(
    'W-11-04 renders the fixture: totals, table, overdue, trend table toggle, hotspots',
    (t) async {
      await pumpDash(t, reduced: true);
      expect(find.byKey(const Key('wardDash.categoryTable')), findsOneWidget);
      expect(find.text('Roads'), findsWidgets);
      expect(find.text('Pothole near the school'), findsOneWidget);
      expect(find.text('15 days old', findRichText: true), findsNothing);
      expect(find.textContaining('15 days old'), findsOneWidget);
      expect(find.textContaining('5 open issues near'), findsOneWidget);
      expect(find.byKey(const Key('wardDash.election')), findsNothing);
      await t.tap(find.byKey(const Key('wardDash.trendToggle')));
      await t.pump();
      expect(find.byKey(const Key('wardDash.trendTable')), findsOneWidget);
      expect(find.text('2026-07-21'), findsOneWidget);
    },
  );

  testWidgets(
    'W-11-04 empty ward, error with Try again, election banner, offline last-good',
    (t) async {
      final api = FakeRepConsoleApi()
        ..open = 0
        ..election = true;
      final (c, _) = await pumpDash(t, reduced: true, api: api);
      expect(find.byKey(const Key('wardDash.empty')), findsOneWidget);
      expect(find.byKey(const Key('wardDash.election')), findsOneWidget);
      api.offline = true;
      c.invalidate(wardDashboardProvider('w12'));
      await t.pump();
      await t.pump();
      expect(find.byKey(const Key('wardDash.stale')), findsOneWidget);
      api
        ..offline = false
        ..failNext = const AppError(code: 'INTERNAL');
      c.read(selectedWardProvider.notifier).select('w13');
      await t.pump();
      await t.pump();
      await t.pump(SaartheeMotion.short.duration);
      expect(find.byKey(const Key('staff.error')), findsOneWidget);
    },
  );

  testWidgets('W-11-07 count-up and bar growth on first view only, per ward', (
    t,
  ) async {
    final (c, _) = await pumpDash(t);
    expect(tile(t, 'open'), '0');
    expect(barScale(t, 11), 0);
    await t.pump(SaartheeMotion.countUp.duration ~/ 2);
    final mid = int.parse(tile(t, 'open'));
    expect(mid, inInclusiveRange(0, 9));
    await t.pump(SaartheeMotion.long.duration);
    expect(tile(t, 'open'), '9');
    expect(tile(t, 'overdue'), '3');
    expect(barScale(t, 11), 1);

    // Refresh: final values in one frame, no replay.
    c.invalidate(wardDashboardProvider('w12'));
    await t.pump();
    await t.pump();
    expect(tile(t, 'open'), '9');
    expect(barScale(t, 11), 1);

    // Ward 13: animates once on its first view.
    c.read(selectedWardProvider.notifier).select('w13');
    await t.pump();
    await t.pump();
    await t.pump(SaartheeMotion.short.duration);
    expect(tile(t, 'open'), isNot('9'));
    await t.pump(SaartheeMotion.long.duration);
    expect(tile(t, 'open'), '9');

    // Back to ward 12 and the table toggle: no replay.
    c.read(selectedWardProvider.notifier).select('w12');
    await t.pump();
    await t.pump();
    await t.pump(SaartheeMotion.short.duration);
    expect(tile(t, 'open'), '9');
    await t.pumpAndSettle();
    expect(tile(t, 'open'), '9');
    await t.tap(find.byKey(const Key('wardDash.trendToggle')));
    await t.pump();
    await t.tap(find.byKey(const Key('wardDash.trendToggle')));
    await t.pump();
    expect(barScale(t, 11), 1);
    await t.pumpAndSettle();
  });

  for (final variant in ['system', 'in-app']) {
    testWidgets(
      'W-11-08 reduced motion ($variant): final values in the first frame',
      (t) async {
        await pumpDash(
          t,
          reduced: variant == 'in-app' ? true : null,
          disableAnimations: variant == 'system',
        );
        expect(tile(t, 'open'), '9');
        expect(tile(t, 'overdue'), '3');
        expect(tile(t, 'fixed30'), '1');
        expect(tile(t, 'verified30'), '1');
        expect(barScale(t, 11), 1);
      },
    );
  }
}
