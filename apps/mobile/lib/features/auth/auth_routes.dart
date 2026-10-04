import 'package:go_router/go_router.dart';

import '../../router/route_helpers.dart';
import 'application/phone_sign_in.dart';
import 'presentation/age_screen.dart';
import 'presentation/blocked_screen.dart';
import 'presentation/otp_screen.dart';
import 'presentation/sign_in_screen.dart';

/// Full-screen sign-in flow above the shell (root navigator), TASK-04 §5.4.
final List<RouteBase> authRoutes = <RouteBase>[
  saartheeRoute(
    path: '/sign-in',
    builder: (_, state) => SignInScreen(
      from: state.uri.queryParameters['from'],
      reason: SignInReason.parse(state.uri.queryParameters['reason']),
    ),
  ),
  saartheeRoute(path: '/sign-in/otp', builder: (_, _) => const OtpScreen()),
  saartheeRoute(path: '/sign-in/age', builder: (_, _) => const AgeScreen()),
  saartheeRoute(
    path: '/sign-in/blocked',
    builder: (_, _) => const BlockedScreen(),
  ),
];
