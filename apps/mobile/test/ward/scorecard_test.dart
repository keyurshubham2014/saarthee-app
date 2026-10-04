// W-09-04 scorecard states and W-09-07 shared ScorecardStatTile /
// ScorecardBar motion (AC-9, AC-11, AC-14, AC-15).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/theme/motion.dart';
import 'package:saarthee/core/widgets/scorecard/scorecard.dart';
import 'package:saarthee/features/ward/data/ward_api.dart';

import '../helpers/motion.dart';
import 'ward_fakes.dart';

const _ms = Duration(milliseconds: 1);

WardScorecard card({
  double? ack = 2,
  double? fix = 5.5,
  double? verified = 75,
  double? reopen = 16.7,
  double? per1000 = 0.2,
  int? population = 50000,
  bool hidden = false,
}) => WardScorecard.fromJson({
  'wardId': wardId,
  'hidden': hidden,
  if (hidden) 'until': '2026-11-01T00:00:00.000Z',
  'windowDays': 90,
  'refreshedAt': '2026-10-04T04:30:00.000Z',
  'metrics': {
    'issuesReported': 12,
    'medianDaysAck': ack,
    'medianDaysFix': fix,
    'verifiedPct': verified,
    'reopenPct': reopen,
    'openBacklog': 8,
    'reportsPer1000': per1000,
  },
  'population': {
    'value': population,
    'sourceNote': population == null ? null : 'Census',
  },
});

String _tileText(WidgetTester t, String key) => t
    .widget<Text>(
      find.descendant(
        of: find.byKey(Key(key)),
        matching: find.byKey(const Key('scorecardTile.value')),
      ),
    )
    .data!;

double _barScale(WidgetTester t, {int index = 0}) {
  final tr = t.widget<Transform>(
    find.byKey(const Key('scorecardBar.fill')).at(index),
  );
  return tr.transform.storage[0];
}

void main() {
  group('W-09-04 scorecard screen states', () {
    testWidgets('values, method note, small sample and missing population', (
      t,
    ) async {
      final api = FakeWardApi(
        card: card(ack: null, fix: null, per1000: null, population: null),
      );
      await pumpWardRoutes(t, api: api, initial: '/ward/$wardId/scorecard');
      await t.pumpAndSettle();
      expect(find.text('Not enough reports yet'), findsNWidgets(2));
      expect(find.text('Ward population not available'), findsOneWidget);
      expect(_tileText(t, 'scorecard.verified'), '75%');
      expect(_tileText(t, 'scorecard.backlog'), '8');
      expect(find.textContaining('Last 90 days · Updated'), findsOneWidget);
      await t.scrollUntilVisible(
        find.byKey(const Key('scorecard.method')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await t.tap(find.text('How we calculate this'));
      await t.pumpAndSettle();
      expect(
        find.textContaining(
          "Based only on reports made in Saarthee, not AMC's records.",
        ),
        findsOneWidget,
      );
    });

    testWidgets('election mode → banner + paused message', (t) async {
      await pumpWardRoutes(
        t,
        api: FakeWardApi(card: card(hidden: true)),
        initial: '/ward/$wardId/scorecard',
      );
      await t.pumpAndSettle();
      expect(find.byKey(const Key('ward.electionBanner')), findsOneWidget);
      expect(
        find.text('The scorecard is paused during the election period.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('scorecard.verified')), findsNothing);
    });
  });

  group('W-09-07 ScorecardStatTile / ScorecardBar', () {
    Widget tiles({double verified = 75, double fix = 5.5, String key = 'k1'}) =>
        Column(
          children: [
            ScorecardStatTile(
              key: const Key('t.verified'),
              value: verified,
              suffix: '%',
              label: 'Verified',
              animateKey: '$key:verified',
              barFraction: verified / 100,
            ),
            ScorecardStatTile(
              key: const Key('t.fix'),
              value: fix,
              decimals: 1,
              label: 'Fix',
              animateKey: '$key:fix',
            ),
          ],
        );

    testWidgets(
      'first view counts up in integers and grows the bar; same key later shows final at once',
      (t) async {
        final content = ValueNotifier<Widget>(tiles());
        addTearDown(content.dispose);
        await pumpMotion(
          t,
          ValueListenableBuilder<Widget>(
            valueListenable: content,
            builder: (_, w, _) => w,
          ),
          reduced: false,
        );
        expect(_tileText(t, 't.verified'), '0%');
        expect(_barScale(t), 0);
        await t.pump(SaartheeMotion.countUp.duration ~/ 2);
        final mid = _tileText(t, 't.verified');
        final midValue = int.parse(mid.replaceAll('%', ''));
        expect(midValue, inExclusiveRange(0, 75));
        // One-decimal median: integer part while counting.
        expect(_tileText(t, 't.fix'), isNot(contains('.')));
        expect(_barScale(t), inExclusiveRange(0, 1));
        await t.pump(SaartheeMotion.countUp.duration);
        expect(_tileText(t, 't.verified'), '75%');
        expect(_tileText(t, 't.fix'), '5.5');
        expect(_barScale(t), closeTo(1, 1e-9));

        // Rebuild with new data (refresh): final value in one frame, no replay.
        content.value = tiles(verified: 80);
        await t.pump();
        expect(_tileText(t, 't.verified'), '80%');
        expect(_barScale(t), closeTo(1, 1e-9));

        // Leave and come back with the same key later in the session.
        content.value = const SizedBox();
        await t.pump();
        content.value = tiles();
        await t.pump();
        expect(_tileText(t, 't.verified'), '75%');
        expect(_barScale(t), closeTo(1, 1e-9));
      },
    );

    testWidgets('reduced motion: final values and full bar after one pump', (
      t,
    ) async {
      await pumpMotion(t, tiles(key: 'k2'), reduced: true);
      await t.pump();
      expect(_tileText(t, 't.verified'), '75%');
      expect(_tileText(t, 't.fix'), '5.5');
      expect(_barScale(t), closeTo(1, 1e-9));
    });

    testWidgets('semantics read the final value', (t) async {
      final handle = t.ensureSemantics();
      await pumpMotion(t, tiles(key: 'k3'), reduced: false);
      expect(find.bySemanticsLabel('Verified: 75%'), findsOneWidget);
      await t.pump(SaartheeMotion.countUp.duration + _ms);
      handle.dispose();
    });
  });
}
