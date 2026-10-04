// V2-TASK-14 step 17: host-side check that every perf-harness moment
// (integration_test/motion_perf_test.dart) can be arranged and triggered
// with the fakes — no tracing here; the device run measures frames.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/support/motion_moments.dart';

void main() {
  for (final m in allMotionMoments) {
    testWidgets('${m.id} ${m.title} is drivable', (t) async {
      final act = await m.prepare(t);
      await act();
      expect(t.takeException(), isNull);
      // Drop the tree and let toasts / polls / debounces run out.
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(const Duration(minutes: 1));
    }, skip: m.skip != null);
  }
}
