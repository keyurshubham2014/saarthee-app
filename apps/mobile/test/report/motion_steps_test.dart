// W-05-08 (tile pop-in, selection spring + haptic) and W-05-09 (shared-axis
// steps with the persistent step header), normal and reduced (AC-15, AC-18).
import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/theme/motion.dart';
import 'package:saarthee/core/theme/tokens.dart';
import 'package:saarthee/features/report/application/report_draft_controller.dart';
import 'package:saarthee/features/report/presentation/motion/category_tile.dart';

import '../helpers/fake_haptics.dart';
import '../helpers/motion.dart';
import 'report_fakes.dart';
import 'report_harness.dart';

Widget grid({String? selected, ValueChanged<String>? onTap}) =>
    SingleChildScrollView(
      child: Wrap(
        children: [
          for (final (i, s) in kSlugs.indexed)
            SizedBox(
              width: 180,
              child: CategoryTile(
                slug: s,
                label: s,
                index: i,
                selected: selected == s,
                onTap: () => onTap?.call(s),
              ),
            ),
        ],
      ),
    );

double opacityOf(WidgetTester t, String slug) => t
    .widget<Opacity>(
      find
          .ancestor(
            of: find.byKey(ValueKey('report.tile.$slug')),
            matching: find.byType(Opacity),
          )
          .first,
    )
    .opacity;

double popScaleOf(WidgetTester t, String slug) {
  final opacity = find
      .ancestor(
        of: find.byKey(ValueKey('report.tile.$slug')),
        matching: find.byType(Opacity),
      )
      .first;
  // PopIn: Opacity > Transform.scale.
  final tr = t.widget<Transform>(
    find.descendant(of: opacity, matching: find.byType(Transform)).first,
  );
  return tr.transform.storage[0];
}

/// Pumps frame by frame (16 ms) for [d], so timers that start animations
/// mid-way are followed by real frames.
Future<void> pumpFrames(WidgetTester t, Duration d) async {
  final end = t.binding.clock.now().add(d);
  while (t.binding.clock.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  group('W-05-08 step 1 motion', () {
    testWidgets('tiles pop from 0.88 with a 35 ms stagger capped at 6 steps', (
      t,
    ) async {
      await pumpMotion(t, grid());
      expect(opacityOf(t, 'roads'), 0);
      expect(
        popScaleOf(t, 'roads'),
        closeTo(SaartheeMotion.popScaleFrom, 0.001),
      );
      await t.pump();
      await pumpFrames(
        t,
        SaartheeMotion.springIn.duration + SaartheeMotion.tileStagger * 5,
      );
      await t.pump(const Duration(milliseconds: 16));
      for (final s in kSlugs) {
        expect(opacityOf(t, s), 1, reason: s);
        expect(popScaleOf(t, s), closeTo(1, 0.001), reason: s);
      }
      expect(CategoryTile.staggerIndex(13), 5);
      expect(CategoryTile.staggerIndex(3), 3);
    });

    testWidgets('selected tile springs above 1 and back; fill + outline', (
      t,
    ) async {
      String? sel;
      await pumpMotion(
        t,
        StatefulBuilder(
          builder: (c, set) =>
              grid(selected: sel, onTap: (s) => set(() => sel = s)),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('report.tile.garbage')));
      await t.pump();
      final state = t.state<CategoryTileState>(find.byType(CategoryTile).at(3));
      await t.pump(SaartheeMotion.springIn.duration ~/ 2);
      expect(state.springScale, greaterThan(1));
      expect(
        state.springScale,
        lessThanOrEqualTo(SaartheeMotion.selectSpringScale + 1e-9),
      );
      await t.pump(SaartheeMotion.springIn.duration);
      expect(state.springScale, closeTo(1, 1e-6));
      final box = t.widget<AnimatedContainer>(
        find.byKey(const ValueKey('report.tile.garbage.box')),
      );
      final ctx = t.element(find.byType(CategoryTile).first);
      final c = SaartheeColors.of(ctx);
      expect((box.decoration! as BoxDecoration).color, c.primaryContainer);
      final outline =
          (box.foregroundDecoration! as BoxDecoration).border! as Border;
      expect(outline.top.color, c.primary);
      expect(outline.top.width, 2);
    });

    testWidgets(
      'reduced (system flag and in-app switch): final on the first frame',
      (t) async {
        await pumpMotion(t, grid(), disableAnimations: true);
        expect(opacityOf(t, 'roads'), 1);
        expect(opacityOf(t, 'other'), 1);
        await pumpMotion(t, grid(), reduced: true);
        expect(opacityOf(t, 'water'), 1);
        expect(popScaleOf(t, 'water'), 1);
      },
    );

    for (final reduced in [false, true]) {
      testWidgets('tap fires exactly one selection haptic (reduced=$reduced)', (
        t,
      ) async {
        final haptics = FakeSaartheeHaptics();
        final c = await pumpReportApp(
          t,
          api: FakeReportApi(),
          haptics: haptics,
          reduced: reduced,
        );
        await t.tap(find.byKey(const ValueKey('report.tile.garbage')));
        await t.pump();
        await t.pump(SaartheeMotion.short.duration);
        expect(haptics.calls.where((h) => h == 'selection'), hasLength(1));
        await t.pumpAndSettle();
        expect(c.read(reportDraftProvider)!.categorySlug, 'garbage');
        expect(c.read(reportDraftProvider)!.step, ReportStep.photo);
      });
    }
  });

  group('W-05-09 step transitions', () {
    double barValue(WidgetTester t) {
      final paint = t.widget<CustomPaint>(
        find.byKey(const Key('stepHeader.progress')),
      );
      return ((paint.painter! as dynamic).value as double);
    }

    testWidgets(
      'shared axis + bar 2/3 → 3/3, Back reverses to 2/3; header kept',
      (t) async {
        final c = await pumpReportApp(
          t,
          api: FakeReportApi(),
          draft: draftAt(ReportStep.photo),
        );
        expect(barValue(t), closeTo(2 / 3, 1e-6));
        final header = t.element(find.byKey(const Key('report.stepHeader')));
        c.read(reportDraftProvider.notifier).goTo(ReportStep.details);
        await t.pump();
        await t.pump(SaartheeMotion.medium.duration ~/ 2);
        expect(find.byType(SharedAxisTransition), findsWidgets);
        expect(barValue(t), inExclusiveRange(2 / 3, 1));
        await t.pump(SaartheeMotion.medium.duration);
        await t.pumpAndSettle();
        expect(barValue(t), closeTo(1, 1e-6));
        expect(find.text('Step 3 of 3'), findsOneWidget);
        expect(
          identical(
            t.element(find.byKey(const Key('report.stepHeader'))),
            header,
          ),
          isTrue,
        );
        await t.tap(find.byTooltip('Back').first);
        await t.pump();
        await t.pump(SaartheeMotion.medium.duration ~/ 2);
        final switcher = t.widget<PageTransitionSwitcher>(
          find.byType(PageTransitionSwitcher),
        );
        expect(switcher.reverse, isTrue);
        await t.pumpAndSettle();
        expect(barValue(t), closeTo(2 / 3, 1e-6));
        expect(c.read(reportDraftProvider)!.step, ReportStep.photo);
      },
    );

    testWidgets('reduced: no shared axis, bar at target within 100 ms', (
      t,
    ) async {
      final c = await pumpReportApp(
        t,
        api: FakeReportApi(),
        draft: draftAt(ReportStep.photo),
        reduced: true,
      );
      c.read(reportDraftProvider.notifier).goTo(ReportStep.details);
      await t.pump();
      expect(find.byType(SharedAxisTransition), findsNothing);
      await t.pump(const Duration(milliseconds: 100));
      expect(barValue(t), closeTo(1, 1e-6));
    });
  });
}
