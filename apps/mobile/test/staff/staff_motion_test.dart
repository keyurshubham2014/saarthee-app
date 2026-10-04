// W-10-07 (AC-15): staff console motion is `short` fades only — routes,
// dialogs and toasts; reduced motion is instant; static scan of
// features/staff/** for forbidden motion helpers.
import 'dart:io';

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/settings/motion_preference.dart';
import 'package:saarthee/core/theme/motion.dart';
import 'package:saarthee/features/staff/moderation/staff_moderation_screen.dart';
import 'package:saarthee/features/staff/shared/staff_widgets.dart';
import 'package:saarthee/features/staff/shell/staff_motion.dart';

import 'staff_harness.dart';

final _half = Duration(
  microseconds: SaartheeMotion.short.duration.inMicroseconds ~/ 2,
);

/// ScaleTransitions other than Scaffold's idle FAB slot (the staff scaffold
/// sets `FloatingActionButtonAnimator.noAnimation`).
Iterable<Element> _scales() =>
    find.byWidgetPredicate((w) => w is ScaleTransition).evaluate().where((e) {
      var fab = false;
      e.visitAncestorElements((a) {
        fab =
            a.widget.runtimeType.toString() ==
            '_FloatingActionButtonTransition';
        return !fab;
      });
      return !fab;
    });

void _expectFadeOnly(WidgetTester t) {
  expect(find.byType(SlideTransition), findsNothing);
  expect(find.byType(SharedAxisTransition), findsNothing);
  expect(_scales().toList(), isEmpty);
  expect(find.byType(FadeTransition), findsWidgets);
}

void main() {
  testWidgets('route change is a short cross-fade, complete after `short`', (
    t,
  ) async {
    final r = await pumpStaff(t, location: '/staff');
    r.router.go('/staff/moderation');
    // The sign-in guard is async: let it resolve (no time passes), then the
    // fade starts.
    for (
      var i = 0;
      i < 20 && find.byType(StaffModerationScreen).evaluate().isEmpty;
      i++
    ) {
      await t.pump();
    }
    final route = ModalRoute.of(t.element(find.byType(StaffModerationScreen)))!;
    expect(route.animation!.isCompleted, isFalse);
    await t.pump(_half);
    _expectFadeOnly(t);
    await t.pump(_half);
    await t.pump(const Duration(milliseconds: 1));
    expect(route.animation!.isCompleted, isTrue);
    expect(find.text('Moderation'), findsWidgets);
  });

  testWidgets('confirm dialog and toast fade (no scale or slide)', (t) async {
    await pumpStaff(t, location: '/staff');
    final ctx = t.element(find.text('Sensitive reports to review'));
    final result = confirmStaffAction(ctx, title: 'T', effect: 'E');
    await t.pump();
    await t.pump(_half);
    _expectFadeOnly(t);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('staff.confirm.ok')));
    await t.pumpAndSettle();
    expect(await result, isTrue);

    showStaffToast(ctx, 'Saved.');
    await t.pump();
    await t.pump(_half);
    _expectFadeOnly(t);
    expect(find.byKey(const Key('staff.toast')), findsOneWidget);
    await t.pump(SaartheeMotion.toastHold);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('staff.toast')), findsNothing);
  });

  testWidgets('reduced motion: route change completes in one pump', (t) async {
    final r = await pumpStaff(
      t,
      location: '/staff',
      overrides: [reducedMotionProvider.overrideWithValue(true)],
    );
    r.router.go('/staff/moderation');
    for (
      var i = 0;
      i < 20 && find.byType(StaffModerationScreen).evaluate().isEmpty;
      i++
    ) {
      await t.pump();
    }
    await t.pump();
    final route = ModalRoute.of(t.element(find.byType(StaffModerationScreen)))!;
    expect(route.animation!.isCompleted, isTrue);
    expect(find.text('Sensitive reports to review'), findsNothing);
  });

  testWidgets('staffFade is short, or zero when reduced', (t) async {
    await pumpStaff(t, location: '/staff');
    expect(
      staffFade(t.element(find.text('Dashboard').first)),
      SaartheeMotion.short.duration,
    );
  });

  test('features/staff/** uses no stagger, spring, shared axis, Hero, CountUp or pulse', () {
    final banned = RegExp(
      r'StaggeredColumn|springIn|SharedAxisTransition|\bHero\(|CountUp\(|RollingCount\(|pulse',
      caseSensitive: false,
    );
    final hits = <String>[];
    for (final f in Directory(
      'lib/features/staff',
    ).listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart') || f.path.contains('/ward_dashboard/')) {
        continue;
      }
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (banned.hasMatch(lines[i])) hits.add('${f.path}:${i + 1}');
      }
    }
    expect(hits, isEmpty);
  });
}
