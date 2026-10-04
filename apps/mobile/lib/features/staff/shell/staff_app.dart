import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/motion/staff_motion_scope.dart';
import '../../../core/settings/locale_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/motion.dart';
import '../../../router/staff_routes.dart';
import '../../auth/auth_routes.dart';

/// Router of the staff web build: the staff console routes plus the phone
/// sign-in flow; anything else opens the console.
GoRouter buildStaffWebRouter() => GoRouter(
  initialLocation: '/staff',
  redirect: (_, state) {
    final p = state.uri.path;
    return p.startsWith('/staff') || p.startsWith('/sign-in') ? null : '/staff';
  },
  routes: [...staffRoutes, ...authRoutes],
);

final staffWebRouterProvider = Provider<GoRouter>((ref) {
  final router = buildStaffWebRouter();
  ref.onDispose(router.dispose);
  return router;
});

/// The staff web app (`main_staff.dart`): Neem theme, gu/en (English by
/// default on the web, from the browser locale), and `StaffMotionScope`
/// around everything — routes, dialogs, sheets and toasts use `short` fades.
class StaffWebApp extends ConsumerWidget {
  const StaffWebApp({super.key, this.router});

  final GoRouter? router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      onGenerateTitle: (c) => AppLocalizations.of(c).staffConsoleTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: ref.watch(localeProvider),
      routerConfig: router ?? ref.watch(staffWebRouterProvider),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('gu'), Locale('en')],
      builder: (context, child) => MotionScope(
        child: StaffMotionScope(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}
