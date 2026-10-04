import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion/motion_widgets.dart';
import '../../router/route_helpers.dart';
import '../auth/application/ensure_signed_in.dart';
import 'presentation/blur_screen.dart';
import 'presentation/done_screen.dart';
import 'presentation/link_ccrs_screen.dart';
import 'presentation/report_flow_screen.dart';

/// The Report tab body (`/report`), replacing the P-05 placeholder.
Widget buildReportTab(BuildContext context, GoRouterState state) =>
    ReportFlowScreen(stepParam: state.uri.queryParameters['step']);

/// Step paths and retired v1 report paths open the flow at a step
/// (`/report?step=…`); the flow keeps one persistent step header.
String? _toStep(GoRouterState state, String path, String step) =>
    state.uri.path == path ? '/report?step=$step' : null;

GoRoute _stepAlias(String segment, String step) => GoRoute(
  path: segment,
  redirect: (_, s) => _toStep(s, '/report/$segment', step),
  builder: (_, _) => const SizedBox.shrink(),
);

/// `/report/done`: full-screen success above the shell, opened with a fade.
GoRoute reportDoneRoute(GlobalKey<NavigatorState> rootKey) => GoRoute(
  path: 'done',
  parentNavigatorKey: rootKey,
  pageBuilder: (context, state) {
    final spec = SaartheeMotion.of(context).medium;
    return CustomTransitionPage<void>(
      key: state.pageKey,
      transitionDuration: spec.duration,
      reverseTransitionDuration: spec.duration,
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
      child: const ReportDoneScreen(),
    );
  },
);

/// Child routes of `/report` (TASK-05).
List<RouteBase> reportRoutes(GlobalKey<NavigatorState> rootKey) => [
  _stepAlias('what', 'what'),
  // Listed before the `photo` alias so `/report/photo/blur` matches it.
  saartheeRoute(
    path: 'photo/blur',
    parentNavigatorKey: rootKey,
    builder: (_, s) =>
        BlurScreen(photoPath: s.uri.queryParameters['path'] ?? ''),
  ),
  _stepAlias('photo', 'photo'),
  _stepAlias('details', 'details'),
  reportDoneRoute(rootKey),
  // Retired v1 six-step routes (AC-14).
  for (final v1 in ['category', 'file-with-amc', 'number', 'phone', 'check'])
    _stepAlias(v1, 'what'),
];

/// Full-screen routes above the shell (TASK-05).
final List<RouteBase> reportRootRoutes = [
  saartheeRoute(
    path: '/issues/:id/link-ccrs',
    redirect: requireAccountRedirect,
    builder: (_, s) => LinkCcrsScreen(issueId: s.pathParameters['id']!),
  ),
];
