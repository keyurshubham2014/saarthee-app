// I-05-01 (TASK-05 AC-3, AC-13): the full three-step report on the emulator
// with a fake camera and fixed GPS, counting taps after the photo (≤ 4).
// Run by the integrator:
//   flutter test integration_test/report_flow_test.dart -d emulator-5554
// The real-API half (sign-in, POST /photos, POST /issues) is the manual run
// in TASK-05 §13 (adb emu geo fix 72.5714 23.0225 + the emulator camera).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/report/report_fakes.dart';
import '../test/report/report_flow_body.dart';
import '../test/report/report_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('typical report needs ≤ 4 taps after the photo', (t) async {
    final api = FakeReportApi();
    await pumpReportApp(t, api: api, capture: FakeEvidenceCapture());
    final taps = await runTypicalReport(t, api);
    expect(taps, lessThanOrEqualTo(4));
    expect(find.byKey(const Key('report.done')), findsOneWidget);
  });
}
