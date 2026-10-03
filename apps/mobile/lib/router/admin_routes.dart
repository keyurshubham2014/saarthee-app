import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/admin/application/admin_auth.dart';
import '../features/admin/presentation/admin_paths.dart';
import '../features/admin/presentation/auth/admin_login_screen.dart';
import '../features/admin/presentation/complaints/admin_all_screen.dart';
import '../features/admin/presentation/complaints/admin_detail_screen.dart';
import '../features/admin/presentation/due/admin_due_screen.dart';
import '../features/admin/presentation/more/admin_more_screen.dart';
import '../features/admin/presentation/reference/admin_categories_screen.dart';
import '../features/admin/presentation/reference/admin_export_screen.dart';
import '../features/admin/presentation/reference/admin_invite_codes_screen.dart';
import '../features/admin/presentation/rates/admin_rates_screen.dart';
import '../features/admin/presentation/shell/admin_shell.dart';

/// Guard for signed-in admin routes (UX only; the server is authoritative).
/// Waits for the stored session to load, drops expired sessions and sends
/// the operator to `/admin/login?from=<route>`.
FutureOr<String?> _requireAdmin(
  BuildContext context,
  GoRouterState state,
) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final auth = container.read(adminAuthProvider.notifier);
  await auth.ensureRestored();
  auth.checkExpiry();
  if (container.read(adminAuthProvider).isSignedIn) {
    return null;
  }
  return AdminPaths.loginReturningTo(state.uri.toString());
}

/// Signed-in operators skip the login page.
FutureOr<String?> _loginRedirect(
  BuildContext context,
  GoRouterState state,
) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final auth = container.read(adminAuthProvider.notifier);
  await auth.ensureRestored();
  auth.checkExpiry();
  if (container.read(adminAuthProvider).isSignedIn) {
    return safeAdminReturnPath(state.uri.queryParameters['from']);
  }
  return null;
}

/// Admin routes (owned by the admin worker). Included by the app router.
final List<RouteBase> adminRoutes = <RouteBase>[
  GoRoute(
    path: AdminPaths.login,
    redirect: _loginRedirect,
    builder: (context, state) =>
        AdminLoginScreen(from: state.uri.queryParameters['from']),
  ),
  GoRoute(
    path: '/admin/complaints/:id',
    redirect: _requireAdmin,
    builder: (context, state) =>
        AdminDetailScreen(complaintId: state.pathParameters['id'] ?? ''),
  ),
  GoRoute(
    path: AdminPaths.inviteCodes,
    redirect: _requireAdmin,
    builder: (context, state) => const AdminInviteCodesScreen(),
  ),
  GoRoute(
    path: AdminPaths.categories,
    redirect: _requireAdmin,
    builder: (context, state) => const AdminCategoriesScreen(),
  ),
  GoRoute(
    path: AdminPaths.export,
    redirect: _requireAdmin,
    builder: (context, state) => const AdminExportScreen(),
  ),
  StatefulShellRoute.indexedStack(
    redirect: _requireAdmin,
    builder: (context, state, navigationShell) =>
        AdminShell(navigationShell: navigationShell),
    branches: <StatefulShellBranch>[
      StatefulShellBranch(
        routes: <RouteBase>[
          GoRoute(
            path: AdminPaths.due,
            builder: (context, state) => const AdminDueScreen(),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: <RouteBase>[
          GoRoute(
            path: AdminPaths.complaints,
            builder: (context, state) => const AdminAllScreen(),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: <RouteBase>[
          GoRoute(
            path: AdminPaths.rates,
            builder: (context, state) => const AdminRatesScreen(),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: <RouteBase>[
          GoRoute(
            path: AdminPaths.more,
            builder: (context, state) => const AdminMoreScreen(),
          ),
        ],
      ),
    ],
  ),
];
