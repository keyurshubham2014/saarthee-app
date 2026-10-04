// UI steps shared by report_verify_test.dart (TASK-06 I-06-01) and
// report_to_verify_test.dart (TASK-14 AC-2).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/theme/motion.dart';

/// Pumps frames until [finder] matches (the in-button progress never settles).
Future<void> waitFor(WidgetTester t, Finder finder, {int seconds = 20}) async {
  for (var i = 0; i < seconds * 10; i++) {
    await t.pump(SaartheeMotion.short.duration);
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for $finder');
}

/// "Is it fixed?" → Yes / Still not fixed → take the (fake) photo → the
/// distance line for a fix 30 m away → Send.
Future<void> answer(WidgetTester t, {required bool fixed}) async {
  await t.tap(find.byKey(const Key('lifecycle.verify')));
  await waitFor(t, find.byKey(const Key('verify.yes')));
  await t.tap(find.byKey(Key(fixed ? 'verify.yes' : 'verify.no')));
  await waitFor(t, find.byKey(const Key('verify.take')));
  await t.tap(find.byKey(const Key('verify.take')));
  await waitFor(t, find.text("You're about 30 m from the problem."));
  await t.tap(find.byKey(const Key('issueActions.send')));
}
