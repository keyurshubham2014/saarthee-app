import 'package:go_router/go_router.dart';

import '../../router/route_helpers.dart';
import 'presentation/issue_list_screens.dart';

/// TASK-07 routes above the shell: `/issues?ward=&bbox=` (the detail
/// `/issues/:id` stays in issueActionsRoutes, built by IssueDetailScreen).
final List<RouteBase> discoveryRootRoutes = <RouteBase>[
  saartheeRoute(
    path: '/issues',
    builder: (_, s) => IssuesScreen(
      wardId: s.uri.queryParameters['ward'],
      bbox: s.uri.queryParameters['bbox'],
    ),
  ),
];

/// TASK-07 routes in the My Ward branch: My reports, Following.
final List<RouteBase> discoveryMeRoutes = <RouteBase>[
  saartheeRoute(
    path: '/me/reports',
    builder: (_, _) => const MyReportsScreen(),
  ),
  saartheeRoute(
    path: '/me/following',
    builder: (_, _) => const FollowingScreen(),
  ),
];
