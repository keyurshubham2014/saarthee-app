// W-09-06 My Ward stagger (AC-13, AC-15): rows rise 60 ms apart, rows after
// the sixth child enter with the sixth, no replay on return, reduced motion
// shows everything at once.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/theme/motion.dart';

import 'ward_fakes.dart';

const _ms = Duration(milliseconds: 1);

double _opacity(WidgetTester t, String key) => t
    .widget<Opacity>(
      find
          .ancestor(of: find.byKey(Key(key)), matching: find.byType(Opacity))
          .first,
    )
    .opacity;

double _dy(WidgetTester t, String key) => t
    .widget<Transform>(
      find
          .ancestor(of: find.byKey(Key(key)), matching: find.byType(Transform))
          .first,
    )
    .transform
    .getTranslation()
    .y;

/// Advances fake time by [d], then one frame so animations started by a
/// stagger timer inside [d] have ticked.
Future<void> _advance(WidgetTester t, Duration d) async {
  await t.pump(d);
  await t.pump(_ms * 16);
}

void main() {
  // Column order: 0 "Corporators", 1–4 corporators c0–c3, 5 "MLA", 6 2-AC
  // note, 7–8 MLAs, 9 "MP", 10 MP, then office and scorecard rows.
  testWidgets(
    'rows rise in order, 60 ms apart; later rows with the 6th; no replay on return',
    (t) async {
      final r = await pumpWardRoutes(t, api: FakeWardApi());
      await t.pump(); // data
      await t.pump();
      expect(_opacity(t, 'ward.rep.c0'), 0);
      expect(_dy(t, 'ward.rep.c0'), SaartheeMotion.riseOffset);

      await _advance(t, SaartheeMotion.stagger + _ms * 20);
      expect(_opacity(t, 'ward.rep.c0'), greaterThan(0));
      expect(_opacity(t, 'ward.rep.c1'), 0);

      // c3 is child 4: starts at 4 × 60 ms.
      await _advance(t, SaartheeMotion.stagger * 2);
      expect(_opacity(t, 'ward.rep.c3'), 0);
      await _advance(t, SaartheeMotion.stagger);
      expect(_opacity(t, 'ward.rep.c3'), greaterThan(0));

      // Children 7+ (the MLAs) enter together with child 5 at 5 × 60 ms.
      expect(_opacity(t, 'ward.rep.m0'), 0);
      await _advance(t, SaartheeMotion.stagger + _ms * 10);
      expect(_opacity(t, 'ward.rep.m0'), greaterThan(0));
      expect(_opacity(t, 'ward.rep.m0'), _opacity(t, 'ward.rep.p0'));

      await t.pumpAndSettle();
      expect(_opacity(t, 'ward.rep.p0'), 1);
      expect(_dy(t, 'ward.rep.p0'), 0);

      // Leave and return: one frame shows every row at rest.
      r.router.go('/');
      await t.pumpAndSettle();
      r.router.go('/ward/$wardId');
      await t.pump();
      await t.pump();
      for (final id in ['c0', 'c3', 'm1', 'p0']) {
        expect(_opacity(t, 'ward.rep.$id'), 1, reason: id);
        expect(_dy(t, 'ward.rep.$id'), 0, reason: id);
      }
    },
  );

  testWidgets(
    'reduced motion (system "Remove animations"): rows at rest after one pump',
    (t) async {
      await pumpWardRoutes(t, api: FakeWardApi(), disableAnimations: true);
      await t.pump();
      await t.pump();
      for (final id in ['c0', 'c3', 'm1', 'p0']) {
        expect(_opacity(t, 'ward.rep.$id'), 1, reason: id);
        expect(_dy(t, 'ward.rep.$id'), 0, reason: id);
      }
    },
  );

  testWidgets('in-app Animations switch off: rows at rest after one pump', (
    t,
  ) async {
    await pumpWardRoutes(t, api: FakeWardApi(), reduced: true);
    await t.pump();
    await t.pump();
    expect(_opacity(t, 'ward.rep.c3'), 1);
    expect(_opacity(t, 'ward.rep.p0'), 1);
  });
}
