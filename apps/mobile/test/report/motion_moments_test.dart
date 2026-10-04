// W-05-10 (photo fly-in, pin drop), W-05-11 (duplicate slide, Add me too →
// Added ✓), W-05-12 (full-screen success) — normal and reduced (AC-16..18).
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/map/civic_map.dart';
import 'package:saarthee/core/motion/motion_check.dart';
import 'package:saarthee/core/theme/motion.dart';
import 'package:saarthee/features/report/application/report_draft_controller.dart';
import 'package:saarthee/features/report/presentation/motion/duplicate_motion.dart';
import 'package:saarthee/features/report/presentation/motion/photo_fly_in.dart';
import 'package:saarthee/features/report/presentation/motion/success_hero.dart';

import '../helpers/fake_haptics.dart';
import '../helpers/motion.dart';
import 'report_fakes.dart';
import 'report_harness.dart';

const _from = Rect.fromLTWH(20, 600, 120, 48);
const _to = Rect.fromLTWH(20, 200, 112, 84);

Widget _launcher(ValueChanged<BuildContext> onReady) => Builder(
  builder: (c) {
    onReady(c);
    return const SizedBox.expand();
  },
);

void main() {
  group('W-05-10 photo fly-in and pin drop', () {
    testWidgets('thumbnail flies from the button rect to the slot over long', (
      t,
    ) async {
      late BuildContext ctx;
      await pumpMotion(t, _launcher((c) => ctx = c));
      final image = FileImage(File(writeTestJpeg()));
      var done = false;
      unawaited(
        flyPhotoIn(
          context: ctx,
          from: _from,
          to: _to,
          image: image,
        ).then((_) => done = true),
      );
      await t.pump();
      final s = t.state<FlyingThumbState>(find.byType(FlyingThumb));
      expect(s.rect, _from);
      expect(find.byKey(const Key('report.flyIn')), findsOneWidget);
      await t.pump(SaartheeMotion.long.duration ~/ 2);
      expect(s.rect.top, inExclusiveRange(_to.top, _from.top));
      await t.pump(SaartheeMotion.long.duration);
      await t.pump();
      expect(find.byKey(const Key('report.flyIn')), findsNothing);
      expect(done, isTrue);
    });

    testWidgets('reduced: no overlay, the slot shows the photo at once', (
      t,
    ) async {
      late BuildContext ctx;
      await pumpMotion(t, _launcher((c) => ctx = c), reduced: true);
      await flyPhotoIn(
        context: ctx,
        from: _from,
        to: _to,
        image: FileImage(File(writeTestJpeg())),
      );
      await t.pump();
      expect(find.byType(FlyingThumb), findsNothing);
    });

    testWidgets('pin drops 24 dp with springIn once', (t) async {
      await pumpMotion(
        t,
        const Center(child: PinDrop(color: Color(0x00000000))),
      );
      final s = t.state<PinDropState>(find.byType(PinDrop));
      expect(s.offset, closeTo(-24, 0.01));
      await t.pump(SaartheeMotion.springIn.duration);
      await t.pump();
      expect(s.offset, closeTo(0, 0.01));
    });

    testWidgets('reduced: pin placed on the first frame', (t) async {
      await pumpMotion(
        t,
        const Center(child: PinDrop(color: Color(0x00000000))),
        reduced: true,
      );
      expect(t.state<PinDropState>(find.byType(PinDrop)).offset, 0);
    });

    testWidgets('no re-drop after Adjust pin and an arrow move', (t) async {
      final c = await pumpReportApp(
        t,
        api: FakeReportApi(),
        draft: draftAt(ReportStep.photo),
      );
      await tapVisible(t, find.byKey(const Key('report.adjustPin')));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Move pin north'));
      await t.pump();
      expect(t.state<PinDropState>(find.byType(PinDrop)).offset, 0);
      final d = c.read(reportDraftProvider)!;
      expect(d.pinAdjusted, isTrue);
      expect(d.pin!.lat, greaterThan(23.0225));
    });
  });

  group('W-05-11 duplicate card and Add me too', () {
    testWidgets('card slides from above the map edge and settles', (t) async {
      await pumpMotion(
        t,
        const DuplicateCardSlide(child: SizedBox(height: 120, width: 300)),
      );
      final s = t.state<DuplicateCardSlideState>(
        find.byType(DuplicateCardSlide),
      );
      expect(s.hiddenFraction, closeTo(1, 1e-6));
      await t.pump(SaartheeMotion.springIn.duration);
      await t.pump();
      expect(s.hiddenFraction, closeTo(0, 1e-6));
    });

    testWidgets(
      'progress → Added ✓ with a drawn check → then the confirmation',
      (t) async {
        final api = Completer<bool>();
        var added = 0;
        final haptics = FakeSaartheeHaptics();
        await pumpMotion(
          t,
          Center(
            child: MeTooButton(
              onPressed: () => api.future,
              onAdded: () => added++,
            ),
          ),
          haptics: haptics,
        );
        await t.tap(find.byKey(const Key('report.dup.addMeToo')));
        await t.pump();
        expect(find.byKey(const ValueKey('meToo.progress')), findsOneWidget);
        expect(haptics.calls, ['light']);
        api.complete(true);
        await t.pump();
        await t.pump(SaartheeMotion.short.duration);
        expect(find.byKey(const ValueKey('meToo.added')), findsOneWidget);
        expect(find.text('Added'), findsOneWidget);
        expect(added, 0, reason: 'confirmation waits for the check');
        await t.pump(
          SaartheeMotion.drawCheckDelay + SaartheeMotion.drawCheck.duration,
        );
        await t.pump();
        final check = t.state(find.byType(MotionCheck)) as dynamic;
        expect(check.progress as double, 1);
        expect(added, 1);
      },
    );

    testWidgets(
      'reduced: label swaps at once, confirmation on the next frame',
      (t) async {
        final api = Completer<bool>();
        var added = 0;
        await pumpMotion(
          t,
          Center(
            child: MeTooButton(
              onPressed: () => api.future,
              onAdded: () => added++,
            ),
          ),
          reduced: true,
        );
        await t.tap(find.byKey(const Key('report.dup.addMeToo')));
        await t.pump();
        api.complete(true);
        await t.pump();
        expect(find.byKey(const ValueKey('meToo.added')), findsOneWidget);
        await t.pump();
        expect(added, 1);
      },
    );

    testWidgets('slide is instant with reduced motion', (t) async {
      await pumpMotion(
        t,
        const DuplicateCardSlide(child: SizedBox(height: 80)),
        reduced: true,
      );
      expect(
        t
            .state<DuplicateCardSlideState>(find.byType(DuplicateCardSlide))
            .hiddenFraction,
        closeTo(0, 1e-6),
      );
    });
  });

  group('W-05-12 success screen', () {
    Widget hero() => const Center(
      child: ReportSuccessHero(
        checkLabel: 'Report sent. Thank you.',
        issueNumber: Text('Issue SA-3F9A2C1B'),
      ),
    );

    double numberOpacity(WidgetTester t) => t
        .widget<Opacity>(
          find
              .descendant(
                of: find.byKey(const Key('report.success.number')),
                matching: find.byType(Opacity),
              )
              .first,
        )
        .opacity;

    testWidgets(
      'circle springs in, check draws after 150 ms, number rises, one success haptic',
      (t) async {
        final haptics = FakeSaartheeHaptics();
        await pumpMotion(t, hero(), haptics: haptics);
        final s = t.state<ReportSuccessHeroState>(
          find.byType(ReportSuccessHero),
        );
        final check = t.state(find.byType(MotionCheck)) as dynamic;
        expect(s.circleScale, closeTo(0, 1e-6));
        await t.pump(const Duration(milliseconds: 140));
        expect(check.progress as double, 0);
        expect(haptics.calls, isEmpty);
        await t.pump(const Duration(milliseconds: 20));
        expect(haptics.calls, ['success']);
        await t.pump(SaartheeMotion.springIn.duration);
        expect(s.circleScale, closeTo(1, 1e-6));
        await t.pump(SaartheeMotion.drawCheck.duration);
        await t.pump();
        expect(check.progress as double, 1);
        for (var i = 0; i < 60; i++) {
          await t.pump(const Duration(milliseconds: 16));
        }
        expect(numberOpacity(t), 1);
        await t.pump(const Duration(seconds: 2));
        expect(t.hasRunningAnimations, isFalse);
        expect(haptics.calls, ['success']);
      },
    );

    testWidgets('reduced: final state on the first frame, one success haptic', (
      t,
    ) async {
      final haptics = FakeSaartheeHaptics();
      await pumpMotion(t, hero(), haptics: haptics, reduced: true);
      final s = t.state<ReportSuccessHeroState>(find.byType(ReportSuccessHero));
      expect(s.circleScale, closeTo(1, 1e-6));
      expect(
        (t.state(find.byType(MotionCheck)) as dynamic).progress as double,
        1,
      );
      expect(numberOpacity(t), 1);
      await t.pump();
      expect(haptics.calls, ['success']);
    });

    testWidgets(
      'done screen announces "Report sent. Issue SA-…" with no particles',
      (t) async {
        final api = FakeReportApi();
        await pumpReportApp(
          t,
          api: api,
          draft: draftAt(ReportStep.details, slug: 'roads'),
        );
        await tapVisible(t, find.byKey(const Key('report.submit')));
        await t.pumpAndSettle();
        final handle = t.ensureSemantics();
        expect(
          find.bySemanticsLabel('Report sent. Issue SA-3F9A2C1B'),
          findsOneWidget,
        );
        handle.dispose();
        final names = t.allWidgets.map(
          (w) => w.runtimeType.toString().toLowerCase(),
        );
        expect(
          names.where(
            (n) =>
                n.contains('lottie') ||
                n.contains('rive') ||
                n.contains('confetti') ||
                n.contains('particle'),
          ),
          isEmpty,
        );
      },
    );
  });
}
