// T-12-20 (AC-13) RSVP morph + rolling count, and T-12-21 (AC-14) the
// reduced-motion variant (system flag and in-app switch).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/motion/motion_check.dart';
import 'package:saarthee/core/theme/motion.dart';
import 'package:saarthee/core/theme/tokens.dart';
import 'package:saarthee/features/initiatives/presentation/widgets/rsvp_button.dart';

import '../helpers/fake_haptics.dart';
import '../services/fakes.dart';
import '../services/harness.dart';

final _button = find.byKey(const Key('rsvp.button'));

BoxDecoration _decoration(WidgetTester t) {
  final box = t.widget<DecoratedBox>(
    find.descendant(of: _button, matching: find.byType(DecoratedBox)).first,
  );
  return box.decoration as BoxDecoration;
}

Color _primaryContainer(WidgetTester t) =>
    SaartheeColors.of(t.element(_button)).primaryContainer;

String _count(WidgetTester t) => t
    .widgetList<Text>(find.descendant(of: find.byKey(const Key('rsvp.countValue')), matching: find.byType(Text)))
    .map((w) => w.data)
    .join(',');

double _checkProgress(WidgetTester t) =>
    (t.state(find.byType(MotionCheck)) as dynamic).progress as double;

Future<(FakeInitiativesRepository, FakeSaartheeHaptics)> _open(
  WidgetTester t, {
  bool? reduced,
  bool disableAnimations = false,
}) async {
  final repo = FakeInitiativesRepository([drive(going: 3, capacity: 20)]);
  final haptics = FakeSaartheeHaptics();
  await pumpServices(
    t,
    location: '/initiatives/i1',
    initiatives: repo,
    haptics: haptics,
    signIn: SignInRecorder([]),
    reduced: reduced,
    disableAnimations: disableAnimations,
  );
  await t.scrollUntilVisible(_button, 200);
  return (repo, haptics);
}

void main() {
  testWidgets('T-12-20 tap → progress → pill morph over medium, drawn check, haptic, count rolls; cancel reverses', (t) async {
    final (repo, haptics) = await _open(t);
    final size = t.getSize(_button);
    expect(_count(t), '3');
    expect(_decoration(t).borderRadius, BorderRadius.circular(AppRadii.control));

    repo.rsvpGate = Completer<void>();
    await t.tap(_button);
    await t.pump();
    expect(find.byKey(const Key('rsvp.progress')), findsOneWidget);
    expect(t.getSize(_button), size);

    repo.rsvpGate!.complete();
    await t.pump();
    await t.pump();
    await t.pump(SaartheeMotion.medium.duration ~/ 2);
    expect(t.getSize(_button), size, reason: 'no layout animation during the morph');
    await t.pump(SaartheeMotion.medium.duration);
    expect(_decoration(t).borderRadius, BorderRadius.circular(RsvpButton.pillRadius));
    expect(_decoration(t).color, _primaryContainer(t));
    expect(t.getSize(_button), size);
    expect(find.text("You're going"), findsOneWidget);
    expect(haptics.calls, ['light']);
    expect(_count(t), '4');

    await t.pump(SaartheeMotion.drawCheckDelay + SaartheeMotion.drawCheck.duration);
    expect(_checkProgress(t), 1.0);
    expect(find.byKey(const Key('rsvp.cancel')), findsOneWidget);

    await t.tap(find.byKey(const Key('rsvp.cancel')));
    await t.pump();
    await t.pump();
    await t.pump(SaartheeMotion.medium.duration);
    await t.pump(SaartheeMotion.short.duration);
    expect(find.text("I'm going"), findsOneWidget);
    expect(_decoration(t).borderRadius, BorderRadius.circular(AppRadii.control));
    expect(_count(t), '3');
    expect(repo.calls, ['rsvp:i1', 'cancel:i1']);
  });

  testWidgets('T-12-20 409 full → no morph, disabled "This drive is full"', (t) async {
    final (repo, haptics) = await _open(t);
    repo.fullOnRsvp = true;
    await t.tap(_button);
    await t.pump();
    await t.pump();
    await t.pump(SaartheeMotion.short.duration);
    expect(find.text('This drive is full'), findsWidgets);
    expect(find.text("You're going"), findsNothing);
    expect(_decoration(t).borderRadius, BorderRadius.circular(AppRadii.control));
    expect(haptics.calls, isEmpty);
    await t.pump(const Duration(seconds: 5));
  });

  for (final (name, reduced, system) in [('system Remove animations', null, true), ('in-app switch off', true, false)]) {
    testWidgets('T-12-21 reduced motion ($name): pill, full check and new count at once', (t) async {
      await _open(t, reduced: reduced, disableAnimations: system);
      await t.tap(_button);
      await t.pump();
      await t.pump();
      expect(find.text("You're going"), findsOneWidget);
      expect(_decoration(t).borderRadius, BorderRadius.circular(RsvpButton.pillRadius));
      expect(_checkProgress(t), 1.0);
      expect(_count(t), '4');
      expect(find.byKey(const Key('rsvp.cancel')), findsOneWidget);
    });
  }
}
