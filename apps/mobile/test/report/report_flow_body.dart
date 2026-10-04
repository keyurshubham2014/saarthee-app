import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'report_fakes.dart';

/// Drives the typical report from step 1 and returns the taps used after the
/// photo was accepted (the camera returns at once in the fake). Shared by the
/// widget test and `integration_test/report_flow_test.dart`.
Future<int> runTypicalReport(WidgetTester t, FakeReportApi api) async {
  await t.tap(find.byKey(const ValueKey('report.tile.roads')));
  await t.pumpAndSettle();
  // Camera opens on entry; blur + upload use real file IO.
  for (var i = 0; i < 40 && api.uploads.isEmpty; i++) {
    await t.pump(const Duration(milliseconds: 50));
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
  }
  await t.pump(const Duration(seconds: 1));
  await t.pumpAndSettle();
  var taps = 0;
  final cont = find.byKey(const Key('report.continue'));
  await t.ensureVisible(cont);
  await t.tap(cont);
  taps++;
  await t.pumpAndSettle();
  final submit = find.byKey(const Key('report.submit'));
  await t.ensureVisible(submit);
  await t.tap(submit);
  taps++;
  await t.pumpAndSettle();
  return taps;
}
