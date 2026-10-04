// T-03-05 buttons and T-03-24 Pressable + haptics.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/motion/haptics.dart';
import 'package:saarthee/core/motion/pressable.dart';
import 'package:saarthee/core/theme/tokens.dart';
import 'package:saarthee/core/widgets/widgets.dart';

import '../helpers/fake_haptics.dart';
import '../helpers/motion.dart';

double _scale(WidgetTester t) =>
    t.widget<AnimatedScale>(find.byType(AnimatedScale).first).scale;

void main() {
  group('T-03-05 buttons', () {
    testWidgets('primary is 50 dp, radius 14, primary fill', (tester) async {
      await pumpMotion(
        tester,
        Center(child: PrimaryButton(label: 'Go', onPressed: () {})),
      );
      final size = tester.getSize(find.byType(FilledButton));
      expect(size.height, AppSpacing.buttonHeight);
      final style = tester.widget<FilledButton>(find.byType(FilledButton));
      final ctx = tester.element(find.byType(FilledButton));
      final resolved = style.style!.backgroundColor!.resolve({});
      expect(resolved, SaartheeColors.of(ctx).primary);
      final theme = Theme.of(ctx).filledButtonTheme.style!;
      final shape = theme.shape!.resolve({}) as RoundedRectangleBorder;
      expect(
        (shape.borderRadius as BorderRadius).topLeft.x,
        AppRadii.control,
      );
    });

    testWidgets('pinned primary is 56 dp', (tester) async {
      await pumpMotion(
        tester,
        Center(
          child: PrimaryButton(label: 'Go', onPressed: () {}, pinned: true),
        ),
      );
      expect(
        tester.getSize(find.byType(FilledButton)).height,
        AppSpacing.pinnedButtonHeight,
      );
    });

    testWidgets('loading disables, shows progress, says Working', (
      tester,
    ) async {
      var taps = 0;
      await pumpMotion(
        tester,
        Center(
          child: PrimaryButton(
            label: 'Go',
            onPressed: () => taps++,
            isLoading: true,
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Go'), findsNothing);
      expect(find.bySemanticsLabel('Working'), findsOneWidget);
      await tester.tap(find.byType(FilledButton), warnIfMissed: false);
      expect(taps, 0);
    });

    testWidgets('SubmitReportButton uses sunrise', (tester) async {
      await pumpMotion(
        tester,
        Center(child: SubmitReportButton(label: 'Send', onPressed: () {})),
      );
      final b = tester.widget<FilledButton>(find.byType(FilledButton));
      final ctx = tester.element(find.byType(FilledButton));
      expect(
        b.style!.backgroundColor!.resolve({}),
        SaartheeColors.of(ctx).sunrise,
      );
    });

    testWidgets('secondary and tertiary render their labels', (tester) async {
      await pumpMotion(
        tester,
        Column(
          children: [
            SecondaryButton(label: 'Second', onPressed: () {}),
            TertiaryButton(label: 'Third', onPressed: () {}),
          ],
        ),
      );
      expect(find.text('Second'), findsOneWidget);
      expect(find.text('Third'), findsOneWidget);
      expect(
        tester.getSize(find.byType(OutlinedButton)).height,
        greaterThanOrEqualTo(48),
      );
    });
  });

  group('T-03-24 Pressable and haptics', () {
    testWidgets('scales to 0.97 while held, back on release, tap fires', (
      tester,
    ) async {
      var taps = 0;
      await pumpMotion(
        tester,
        Center(
          child: Pressable(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => taps++,
              child: const SizedBox(
                key: Key('target'),
                width: 100,
                height: 60,
              ),
            ),
          ),
        ),
      );
      final g = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('target'))),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(_scale(tester), 0.97);
      await g.up();
      await tester.pumpAndSettle();
      expect(_scale(tester), 1);
      expect(taps, 1);
    });

    testWidgets('primary button records a light haptic', (tester) async {
      final fake = FakeSaartheeHaptics();
      await pumpMotion(
        tester,
        Center(child: PrimaryButton(label: 'Go', onPressed: () {})),
        haptics: fake,
      );
      await tester.tap(find.byType(FilledButton));
      expect(fake.calls, ['light']);
    });

    testWidgets('real SaartheeHaptics calls HapticFeedback.vibrate', (
      tester,
    ) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      const h = SaartheeHaptics();
      await h.light();
      await h.selection();
      await h.success();
      expect(calls.map((c) => c.method).toSet(), {'HapticFeedback.vibrate'});
      expect(calls.map((c) => c.arguments), [
        'HapticFeedbackType.lightImpact',
        'HapticFeedbackType.selectionClick',
        'HapticFeedbackType.mediumImpact',
      ]);
    });
  });
}
