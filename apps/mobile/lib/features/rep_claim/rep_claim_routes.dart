import 'package:go_router/go_router.dart';

import '../../router/route_helpers.dart';
import '../auth/application/ensure_signed_in.dart';
import 'presentation/claim_check_screen.dart';
import 'presentation/claim_evidence_screen.dart';
import 'presentation/my_messages_screen.dart';

/// TASK-11 citizen routes (My Ward branch): claim steps behind the sign-in
/// gate (returns here after signing in) and `/me/messages`.
final List<RouteBase> repClaimRoutes = <RouteBase>[
  saartheeRoute(
    path: '/representatives/:id/claim',
    redirect: requireAccountRedirect,
    builder: (_, s) => ClaimEvidenceScreen(repId: s.pathParameters['id']!),
    routes: [
      saartheeRoute(
        path: 'check',
        redirect: requireAccountRedirect,
        builder: (_, s) => ClaimCheckScreen(repId: s.pathParameters['id']!),
      ),
      saartheeRoute(
        path: 'done',
        builder: (_, s) => ClaimDoneScreen(repId: s.pathParameters['id']!),
      ),
    ],
  ),
  saartheeRoute(
    path: '/me/messages',
    redirect: requireAccountRedirect,
    builder: (_, _) => const MyMessagesScreen(),
  ),
];
