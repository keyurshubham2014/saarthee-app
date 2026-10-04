// One DS §6 catalogue moment of the TASK-14 §5.4 motion matrix: [prepare]
// arranges the app (outside the trace) and returns the action that
// triggers the moment (inside `binding.traceAction(reportKey: id)`).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

typedef MomentAction = Future<void> Function();

class MotionMoment {
  const MotionMoment(this.id, this.title, this.prepare, {this.skip});

  /// Report key, e.g. `MO-03`.
  final String id;
  final String title;
  final Future<MomentAction> Function(WidgetTester t) prepare;

  /// Why the moment cannot be driven by this harness (null = runs).
  final String? skip;
}

/// 16 ms frames for [d]: real time on the device (live binding), fake
/// time in widget tests.
Future<void> frames(WidgetTester t, Duration d) async {
  for (var ms = 0; ms < d.inMilliseconds; ms += 16) {
    await t.pump(const Duration(milliseconds: 16));
  }
}

const ms300 = Duration(milliseconds: 300);
const ms600 = Duration(milliseconds: 600);
const ms1200 = Duration(milliseconds: 1200);

/// Pumps (letting real IO run) until [done] or [seconds] pass.
Future<void> waitUntil(
  WidgetTester t,
  bool Function() done, {
  int seconds = 10,
}) async {
  for (var i = 0; i < seconds * 20 && !done(); i++) {
    await t.pump(const Duration(milliseconds: 25));
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
  }
  if (!done()) throw TestFailure('waitUntil timed out');
}

/// Waits for [finder] to appear.
Future<void> waitForWidget(WidgetTester t, Finder finder, {int seconds = 10}) =>
    waitUntil(t, () => finder.evaluate().isNotEmpty, seconds: seconds);

/// Scrolls [key] into view (outside the trace) and taps it.
Future<void> tapKey(WidgetTester t, Key key) async {
  final f = find.byKey(key).first;
  await t.ensureVisible(f);
  await t.pump();
  await t.tap(f);
}
