// AC-3 / REQ-N-007 (I-05-01 in-process twin): the full three-step report with
// a fake camera and GPS needs ≤ 4 taps after the photo (Continue, Submit).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'report_fakes.dart';
import 'report_flow_body.dart';
import 'report_harness.dart';

void main() {
  testWidgets(
    'tile → camera → Continue → Submit report → done (2 taps after the photo)',
    (t) async {
      final api = FakeReportApi();
      await pumpReportApp(t, api: api, capture: FakeEvidenceCapture());
      final taps = await runTypicalReport(t, api);
      expect(taps, lessThanOrEqualTo(4));
      expect(find.byKey(const Key('report.done')), findsOneWidget);
      expect(api.submits.single['categorySlug'], 'roads');
      expect(api.submits.single['pinAdjusted'], false);
    },
  );
}
