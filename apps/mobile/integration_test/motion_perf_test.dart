// TASK-14 step 17 / REQ-N-013: the DS §6 motion performance matrix
// (TASK-14 §5.4, MO-01 … MO-25). Each moment is arranged outside the trace
// and triggered inside `binding.traceAction(reportKey: 'MO-nn')`; the host
// driver (test_driver/perf_driver.dart) turns every trace into a
// TimelineSummary under build/motion and fails a moment over budget.
//
// Fixtures and provider overrides only (integration_test/support/
// perf_app.dart): no API, camera or GPS is needed, so the numbers measure
// the animation, not the network. MO-25 measures the in-app staff screens;
// Flutter web staff fades are timed in Chrome DevTools (TASK-14 §5.6).
//
// Run on the reference phone (profile build), three times:
//   cd apps/mobile && flutter drive --profile \
//     --driver=test_driver/perf_driver.dart \
//     --target=integration_test/motion_perf_test.dart -d <serial> \
//     --dart-define=APP_ENV=test \
//     --dart-define=API_BASE_URL=http://10.0.2.2:4000/api/v1 \
//     --dart-define=AUTH_EMULATOR_HOST=10.0.2.2:9099
// One moment: add --dart-define=MOTION_ONLY=MO-03.
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/motion_moments.dart';

const _only = String.fromEnvironment('MOTION_ONLY');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Real frames at device pace while tracing.
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  for (final m in allMotionMoments) {
    final skip = m.skip ?? (_only.isNotEmpty && m.id != _only ? 'only' : null);
    testWidgets('${m.id} ${m.title}', (t) async {
      final act = await m.prepare(t);
      // One timeline event per RenderObject layout, so the driver can check
      // "no layout pass after the moment's first frame" (§5.6). Reset inside
      // the body: debug builds assert rendering debug vars are unset.
      debugProfileLayoutsEnabled = true;
      try {
        await binding.traceAction(act, reportKey: m.id);
      } finally {
        debugProfileLayoutsEnabled = false;
      }
      await t.pumpWidget(const SizedBox.shrink());
    }, skip: skip != null);
  }
}
