import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/errors/global_error.dart';
import '../core/settings/app_settings.dart';
import '../features/auth/auth_routes.dart';
import '../features/dev/gallery_screen.dart';
import '../features/onboarding/presentation/intro_screen.dart';
import '../features/onboarding/presentation/language_screen.dart';
import '../features/onboarding/presentation/ward_screen.dart';
import '../features/report/report_routes.dart';
import 'admin_routes.dart';
import 'route_helpers.dart';
import 'shell_routes.dart';
import 'staff_routes.dart';

/// Root navigator key, used by the global error handler.
final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Full-screen routes above the shell, appended by feature tasks in their
/// own `// TASK-NN` block (see apps/mobile/README.md).
final List<RouteBase> rootFeatureRoutes = <RouteBase>[
  // TASK-04 accounts: sign-in flow.
  ...authRoutes,
  // TASK-05 report: link an AMC complaint number.
  ...reportRootRoutes,
];

/// Paths reachable before onboarding is done.
bool _isPreOnboardingPath(String path) =>
    path.startsWith('/onboarding') ||
    path.startsWith('/admin') ||
    path.startsWith('/dev') ||
    path == '/error';

/// Citizen routes are portrait-locked; admin routes rotate.
void _applyOrientation(String path) {
  SystemChrome.setPreferredOrientations(
    path.startsWith('/admin')
        ? DeviceOrientation.values
        : const [DeviceOrientation.portraitUp],
  );
}

/// Builds the app router. [enableGallery] registers `/dev/gallery`; it is
/// true only in debug builds (absent in profile and release).
GoRouter buildAppRouter(Ref ref, {bool enableGallery = kDebugMode}) {
  final done = ref.read(appSettingsProvider).onboardingDone;
  final initial = done ? '/' : '/onboarding/language';
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: initial,
    redirect: (context, state) {
      final path = state.uri.path;
      final onboarded = ref.read(appSettingsProvider).onboardingDone;
      if (!onboarded && !_isPreOnboardingPath(path)) {
        return '/onboarding/language';
      }
      return null;
    },
    routes: [
      saartheeRoute(
        path: '/onboarding/language',
        builder: (_, _) => const LanguageScreen(),
      ),
      saartheeRoute(
        path: '/onboarding/intro',
        builder: (_, _) => const IntroScreen(),
      ),
      saartheeRoute(
        path: '/onboarding/ward',
        builder: (_, _) => const WardScreen(),
      ),
      buildCitizenShell(),
      saartheeRoute(
        path: '/error',
        builder: (c, _) =>
            GlobalErrorView(onGoHome: () => GoRouter.of(c).go('/')),
      ),
      if (enableGallery)
        GoRoute(path: '/dev/gallery', builder: (_, _) => const GalleryScreen()),
      ...rootFeatureRoutes,
      ...adminRoutes,
      // TASK-08: staff alert composer and approval (TASK-10 mounts the shell).
      ...staffRoutes,
    ],
  );
  _applyOrientation(initial);
  router.routerDelegate.addListener(() {
    _applyOrientation(router.routerDelegate.currentConfiguration.uri.path);
  });
  return router;
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = buildAppRouter(ref);
  ref.onDispose(router.dispose);
  return router;
});
