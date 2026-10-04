// T-03-27 reduced motion (system flag and in-app switch) and
// T-03-28 StaffMotionScope.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/motion/motion_widgets.dart';
import 'package:saarthee/core/settings/app_settings.dart';

import '../helpers/motion.dart';

Widget _journey() => ListView(
  children: [
    const MotionCheck(color: Colors.black, semanticLabel: 'Done'),
    const CountUp(value: 37),
    StaggeredColumn(children: [for (var i = 0; i < 8; i++) Text('item$i')]),
    const Pressable(child: SizedBox(key: Key('press'), width: 80, height: 40)),
  ],
);

double _check(WidgetTester t) =>
    (t
                .widget<CustomPaint>(
                  find.byWidgetPredicate(
                    (w) => w is CustomPaint && w.painter is CheckPainter,
                  ),
                )
                .painter!
            as CheckPainter)
        .progress;

Future<void> _expectEndStateFast(WidgetTester t) async {
  await t.pump(const Duration(milliseconds: 100));
  expect(_check(t), 1);
  expect(find.text('37'), findsOneWidget);
  for (var i = 0; i < 8; i++) {
    final o = t.widget<Opacity>(
      find
          .ancestor(of: find.text('item$i'), matching: find.byType(Opacity))
          .first,
    );
    expect(o.opacity, 1, reason: 'item$i');
  }
  final g = await t.startGesture(t.getCenter(find.byKey(const Key('press'))));
  await t.pump(const Duration(milliseconds: 100));
  expect(t.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
  await g.up();
}

void main() {
  group('T-03-27 reduced motion', () {
    testWidgets('system Remove animations → end state in 100 ms', (t) async {
      final c = await pumpMotion(t, _journey(), disableAnimations: true);
      await t.pump();
      expect(c.read(reducedMotionProvider), isTrue);
      await _expectEndStateFast(t);
    });

    testWidgets('in-app Animations off → end state in 100 ms', (t) async {
      final prefs = await testPrefs({PrefKeys.animationsEnabled: false});
      final c = await pumpMotion(t, _journey(), prefs: prefs);
      expect(c.read(reducedMotionProvider), isTrue);
      await _expectEndStateFast(t);
      expect(prefs.getBool(PrefKeys.animationsEnabled), isFalse);
    });

    testWidgets('same text with motion on and off', (t) async {
      await pumpMotion(t, _journey(), reduced: true);
      await t.pumpAndSettle();
      final reduced = t
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.data)
          .toList();
      await pumpMotion(t, _journey(), reduced: false);
      await t.pumpAndSettle();
      final full = t
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.data)
          .toList();
      expect(full, reduced);
    });
  });

  group('T-03-28 StaffMotionScope', () {
    testWidgets('inside: short fades, no stagger, no press scale', (t) async {
      late SaartheeMotionScheme scheme;
      await pumpMotion(
        t,
        StaffMotionScope(
          child: Builder(
            builder: (context) {
              scheme = SaartheeMotion.of(context);
              return const Pressable(
                child: SizedBox(key: Key('press'), width: 80, height: 40),
              );
            },
          ),
        ),
      );
      expect(scheme.medium, SaartheeMotion.short);
      expect(scheme.springIn, SaartheeMotion.short);
      expect(scheme.stagger, Duration.zero);
      expect(scheme.riseOffset, 0);
      final g = await t.startGesture(
        t.getCenter(find.byKey(const Key('press'))),
      );
      await t.pump(const Duration(milliseconds: 100));
      expect(t.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
      await g.up();
    });

    testWidgets('outside: full motion', (t) async {
      late SaartheeMotionScheme scheme;
      await pumpMotion(
        t,
        Builder(
          builder: (context) {
            scheme = SaartheeMotion.of(context);
            return const SizedBox();
          },
        ),
      );
      expect(scheme.medium, SaartheeMotion.medium);
      expect(scheme.stagger, SaartheeMotion.stagger);
    });
  });
}
