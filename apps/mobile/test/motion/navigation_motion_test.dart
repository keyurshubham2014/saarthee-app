// T-03-23 navigation motion through token durations; T-03-27 settings
// switch under the system flag.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/settings/motion_preference.dart';
import 'package:saarthee/features/launch/launch_gate.dart';

import '../helpers/app.dart';
import '../helpers/motion.dart';

const _ms = Duration(milliseconds: 1);

double _pillX(WidgetTester t) =>
    t.getTopLeft(find.byKey(const Key('nav.pill'))).dx;

void main() {
  testWidgets('launch mark 0.92 → 1.0 over 280 ms, then gone', (t) async {
    await pumpMotion(t, const LaunchGate(child: Text('first screen')));
    final gate = t.state<LaunchGateState>(find.byType(LaunchGate));
    expect(gate.markScale, closeTo(0.92, 0.001));
    await t.pump(_ms * 16);
    await t.pump(_ms * 280);
    expect(gate.markScale, closeTo(1.0, 0.001));
    await t.pump(_ms * 300);
    await t.pump(_ms * 300);
    expect(find.byKey(const Key('launch.overlay')), findsNothing);
    expect(find.text('first screen'), findsOneWidget);
    expect(t.binding.hasScheduledFrame, isFalse); // nothing loops
  });

  testWidgets('launch under reduced motion: full-size mark', (t) async {
    await pumpMotion(
      t,
      const LaunchGate(child: Text('first screen')),
      reduced: true,
    );
    final gate = t.state<LaunchGateState>(find.byType(LaunchGate));
    expect(gate.markScale, 1);
  });

  testWidgets('nav pill slides to the new tab within 180 ms', (t) async {
    await pumpApp(t, prefs: onboardedPrefs());
    final start = _pillX(t);
    await t.tap(find.byKey(const Key('nav.3')));
    await t.pump();
    await t.pump(_ms * 90);
    final mid = _pillX(t);
    await t.pump(_ms * 200);
    final end = _pillX(t);
    expect(mid, greaterThan(start));
    expect(end, greaterThan(mid));
    await t.pumpAndSettle();
    expect(_pillX(t), end);
  });

  testWidgets('Animations switch: off + disabled under system flag', (t) async {
    final c = await pumpApp(t, prefs: onboardedPrefs());
    c.read(systemDisableAnimationsProvider.notifier).set(true);
    await t.tap(find.byKey(const Key('nav.4')));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      find.byKey(const Key('myWard.settings')),
      120,
      scrollable: find.byType(Scrollable).hitTestable().first,
    );
    await t.ensureVisible(find.byKey(const Key('myWard.settings')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('myWard.settings')));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      find.byKey(const Key('settings.animations')),
      120,
      scrollable: find.byType(Scrollable).hitTestable().first,
    );
    final sw = t.widget<SwitchListTile>(
      find.byKey(const Key('settings.animations')),
    );
    expect(sw.value, isFalse);
    expect(sw.onChanged, isNull);
    expect(
      find.text('Off because Remove animations is on in your phone settings.'),
      findsOneWidget,
    );
    // The stored preference is untouched (applies again when system is off).
    expect(c.read(motionPreferenceProvider), isTrue);
  });
}
