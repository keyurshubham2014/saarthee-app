import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/report_draft_controller.dart';

/// Total report steps (02 §3.1).
const int kReportSteps = 6;

/// Records the current step in the draft (restored after app kill) and
/// handles "Change" from the check screen (`?from=check` returns there).
mixin ReportStepMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  String get stepRoute;

  bool get fromCheck =>
      GoRouterState.of(context).uri.queryParameters['from'] == 'check';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(reportDraftProvider.notifier).setStep(stepRoute);
    });
  }

  /// Goes to [next], or back to the check screen after a "Change".
  void goNext(String next) => context.go(fromCheck ? ReportRoutes.check : next);

  void goBack(String previous) =>
      context.go(fromCheck ? ReportRoutes.check : previous);
}
