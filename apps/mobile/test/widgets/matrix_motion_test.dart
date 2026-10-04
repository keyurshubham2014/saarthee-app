// V2-TASK-14 AC-1: TASK-03 motion widgets in reduced mode — Pressable,
// StaggeredColumn, MotionCheck, CountUp, RollingCount. The first pass
// forces the in-app reduced setting, the second uses the system
// `disableAnimations` flag; both must show final values after one frame.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/motion/count_up.dart';
import 'package:saarthee/core/motion/motion_check.dart';
import 'package:saarthee/core/motion/pressable.dart';
import 'package:saarthee/core/motion/staggered.dart';
import 'package:saarthee/core/theme/icons.dart';
import 'package:saarthee/core/theme/tokens.dart';
import 'package:saarthee/core/widgets/widgets.dart';

import '../helpers/component_matrix.dart';

void main() {
  componentMatrix(
    'Pressable does not scale in reduced mode',
    (l10n) => Pressable(
      child: PrimaryButton(label: l10n.commonContinue, onPressed: () {}),
    ),
    reduced: true,
    check: (t, l10n) async {
      final g = await t.startGesture(
        t.getCenter(find.text(l10n.commonContinue)),
      );
      await t.pump();
      for (final s in t.widgetList<AnimatedScale>(find.byType(AnimatedScale))) {
        expect(s.scale, 1, reason: 'no press scale when reduced');
      }
      await g.up();
      expectSemanticsContaining(l10n.commonContinue);
    },
  );

  componentMatrix(
    'StaggeredColumn shows every child at once in reduced mode',
    (l10n) => StaggeredColumn(
      children: [
        Text(l10n.navHome),
        Text(l10n.navMap),
        Text(l10n.navAlerts),
        Text(l10n.navMyWard),
      ],
    ),
    reduced: true,
    check: (t, l10n) async {
      for (final w in [l10n.navHome, l10n.navMap, l10n.navAlerts]) {
        expect(find.text(w), findsOneWidget);
      }
      for (final o in t.widgetList<Opacity>(find.byType(Opacity))) {
        expect(o.opacity, 1);
      }
      for (final f in t.widgetList<FadeTransition>(
        find.byType(FadeTransition),
      )) {
        expect(f.opacity.value, 1);
      }
    },
  );

  componentMatrix(
    'MotionCheck labelled and fully drawn',
    (l10n) =>
        MotionCheck(color: NeemFixed.white, semanticLabel: l10n.componentDone),
    reduced: true,
    check: (t, l10n) async => expectSemantics(l10n.componentDone),
  );

  componentMatrix(
    'CountUp and RollingCount land on the final value in one frame',
    (l10n) => const _Counters(),
    reduced: true,
    check: (t, l10n) async {
      expect(find.text('42'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      await t.tap(find.byKey(const Key('bump')));
      await t.pump();
      expect(find.text('43'), findsOneWidget, reason: 'CountUp instant');
      expect(find.text('8'), findsOneWidget, reason: 'RollingCount instant');
      expect(find.text('7'), findsNothing, reason: 'no old digit kept');
    },
  );
}

class _Counters extends StatefulWidget {
  const _Counters();

  @override
  State<_Counters> createState() => _CountersState();
}

class _CountersState extends State<_Counters> {
  int n = 0;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      CountUp(value: 42 + n),
      RollingCount(value: 7 + n),
      TextButton(
        key: const Key('bump'),
        onPressed: () => setState(() => n++),
        child: const Icon(SaartheeIcons.check),
      ),
    ],
  );
}
