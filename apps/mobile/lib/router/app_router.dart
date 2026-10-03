import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/errors/global_error.dart';
import '../core/settings/app_settings.dart';
import '../core/theme/tokens.dart';
import '../features/home/presentation/about_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/onboarding/presentation/invite_screen.dart';
import '../features/onboarding/presentation/welcome_screen.dart';
import '../features/report/application/report_draft_controller.dart';
import 'admin_routes.dart';
import 'citizen_routes.dart';

/// Root navigator key, used by the global error handler.
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Page with a short fade between steps; no motion when reduce-motion is on.
Page<void> stepPage(GoRouterState state, Widget child) => CustomTransitionPage(
  key: state.pageKey,
  child: child,
  transitionDuration: AppMotion.step,
  reverseTransitionDuration: AppMotion.step,
  transitionsBuilder: (context, animation, _, child) {
    if (MediaQuery.maybeDisableAnimationsOf(context) == true) return child;
    return FadeTransition(opacity: animation, child: child);
  },
);

/// Citizen routes are portrait-locked; admin routes rotate (02 §2.2).
void _applyOrientation(String path) {
  SystemChrome.setPreferredOrientations(
    path.startsWith('/admin')
        ? DeviceOrientation.values
        : const [DeviceOrientation.portraitUp],
  );
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final settings = ref.read(appSettingsProvider);
  final draft = ref.read(reportDraftProvider);

  // Cold start resumes an unfinished report on its saved step (02 §4.5).
  final initial = !settings.onboardingDone
      ? '/welcome'
      : (draft != null ? draft.step : '/');

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: initial,
    redirect: (context, state) {
      final path = state.uri.path;
      final done = ref.read(appSettingsProvider).onboardingDone;
      if (!done &&
          path != '/welcome' &&
          path != '/invite' &&
          !path.startsWith('/admin') &&
          !path.startsWith('/verify')) {
        return '/welcome';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/welcome',
        pageBuilder: (c, s) => stepPage(s, const WelcomeScreen()),
      ),
      GoRoute(
        path: '/invite',
        pageBuilder: (c, s) => stepPage(s, const InviteScreen()),
      ),
      GoRoute(
        path: '/',
        pageBuilder: (c, s) => stepPage(s, const HomeScreen()),
      ),
      GoRoute(
        path: '/about',
        pageBuilder: (c, s) => stepPage(s, const AboutScreen()),
      ),
      GoRoute(
        path: '/error',
        pageBuilder: (c, s) => stepPage(
          s,
          GlobalErrorView(onGoHome: () => GoRouter.of(c).go('/')),
        ),
      ),
      ...citizenRoutes,
      ...adminRoutes,
    ],
  );

  _applyOrientation(initial);
  router.routerDelegate.addListener(() {
    _applyOrientation(router.routerDelegate.currentConfiguration.uri.path);
  });
  ref.onDispose(router.dispose);
  return router;
});
