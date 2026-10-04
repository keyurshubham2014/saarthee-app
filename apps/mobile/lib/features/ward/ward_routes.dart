import 'package:go_router/go_router.dart';

import '../../router/route_helpers.dart';
import '../auth/application/ensure_signed_in.dart';
import 'presentation/message_screen.dart';
import 'presentation/representative_screen.dart';
import 'presentation/scorecard_screen.dart';
import 'presentation/ward_screen.dart';

/// TASK-09 children of `/ward`: `/ward/:id`, `/ward/:id/scorecard`.
final List<RouteBase> wardFeatureChildRoutes = <RouteBase>[
  saartheeRoute(
    path: ':id',
    builder: (_, state) => WardScreen(wardId: state.pathParameters['id']!),
    routes: [
      saartheeRoute(
        path: 'scorecard',
        builder: (_, state) =>
            ScorecardScreen(wardId: state.pathParameters['id']!),
      ),
    ],
  ),
];

/// TASK-09 top-level routes in the My Ward branch: profile and message form
/// (sign-in required; returns to the form after signing in).
final List<RouteBase> representativeRoutes = <RouteBase>[
  saartheeRoute(
    path: '/representatives/:id',
    builder: (_, state) =>
        RepresentativeScreen(repId: state.pathParameters['id']!),
    routes: [
      saartheeRoute(
        path: 'message',
        redirect: requireAccountRedirect,
        builder: (_, state) => MessageScreen(
          repId: state.pathParameters['id']!,
          issueId: state.uri.queryParameters['issueId'],
        ),
      ),
    ],
  ),
];
