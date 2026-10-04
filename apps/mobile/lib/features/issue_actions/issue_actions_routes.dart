import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../router/route_helpers.dart';
import '../auth/application/ensure_signed_in.dart';
import 'presentation/escalate_screen.dart';
import '../discovery/presentation/issue_detail_screen.dart';
import 'presentation/mark_fixed_screen.dart';
import 'presentation/verify_photo_screen.dart';
import 'presentation/verify_screen.dart';

String _id(GoRouterState s) => s.pathParameters['id']!;

/// TASK-06 routes above the shell: the issue's lifecycle view, the 2-step
/// verify flow, mark fixed and escalate (sign-in required for actions).
/// `/issues/:id/verify/done` (v2.0) and v1 `/verify/*` links redirect.
final List<RouteBase> issueActionsRoutes = <RouteBase>[
  saartheeRoute(
    path: '/issues/:id',
    // TASK-07: the real issue detail (embeds IssueLifecyclePanel).
    builder: (_, s) => IssueDetailScreen(issueId: _id(s)),
    routes: [
      saartheeRoute(
        path: 'verify',
        redirect: requireAccountRedirect,
        builder: (_, s) => VerifyScreen(issueId: _id(s)),
        routes: [
          saartheeRoute(
            path: 'photo',
            builder: (_, s) => VerifyPhotoScreen(
              issueId: _id(s),
              answer: s.uri.queryParameters['answer'] == 'not_fixed'
                  ? 'not_fixed'
                  : 'fixed',
            ),
          ),
          GoRoute(
            path: 'done',
            redirect: (_, s) => '/issues/${_id(s)}',
            builder: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ),
      saartheeRoute(
        path: 'mark-fixed',
        redirect: requireAccountRedirect,
        builder: (_, s) => MarkFixedScreen(issueId: _id(s)),
      ),
      saartheeRoute(
        path: 'escalate',
        redirect: requireAccountRedirect,
        builder: (_, s) => EscalateScreen(issueId: _id(s)),
      ),
    ],
  ),
  // v1 WhatsApp verify links (token flow retired, Spec D11) open Home.
  GoRoute(
    path: '/verify',
    redirect: (_, _) => '/',
    builder: (_, _) => const SizedBox.shrink(),
    routes: [
      GoRoute(
        path: ':token',
        redirect: (_, _) => '/',
        builder: (_, _) => const SizedBox.shrink(),
      ),
    ],
  ),
];
