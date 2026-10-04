import 'package:go_router/go_router.dart';

import '../features/staff/alerts/presentation/staff_alert_composer_screen.dart';
import '../features/staff/alerts/presentation/staff_alert_detail_screen.dart';
import '../features/staff/alerts/presentation/staff_alerts_list_screen.dart';
import '../features/staff/categories/staff_categories_screen.dart';
import '../features/staff/claims/staff_claim_detail_screen.dart';
import '../features/staff/claims/staff_claims_screen.dart';
import '../features/staff/messages/rep_messages_screen.dart';
import '../features/staff/ward_dashboard/ward_dashboard_screen.dart';
import '../features/staff/ward_dashboard/ward_issues_screen.dart';
import '../features/staff/content/staff_content_routes.dart';
import '../features/staff/dashboard/staff_dashboard_screen.dart';
import '../features/staff/exports/staff_exports_screen.dart';
import '../features/staff/issues/staff_issue_screen.dart';
import '../features/staff/moderation/staff_moderation_screen.dart';
import '../features/staff/settings/staff_settings_screen.dart';
import '../features/staff/shell/staff_login_screen.dart';
import '../features/staff/shell/staff_motion.dart';
import '../features/staff/shell/staff_session.dart';
import '../features/staff/shell/staff_shell.dart';
import '../features/staff/users/staff_users_screen.dart';

/// Staff console routes (`/staff/...`), shared by the app and the staff web
/// build (`main_staff.dart`). TASK-10 owns the shell: every page below is
/// mounted in [StaffShell] (side navigation, header, `StaffMotionScope`) and
/// uses `short` fades only. Role checks here are UX only (the API enforces
/// them). Append-only: each task adds a `// TASK-NN` block inside the shell.
final List<RouteBase> staffRoutes = <RouteBase>[
  staffRoute(path: '/staff/login', builder: (_, _) => const StaffLoginScreen()),
  ShellRoute(
    pageBuilder: (context, state, child) => staffPage<void>(
      context,
      state,
      StaffShell(location: state.uri.path, child: child),
    ),
    routes: [
      // TASK-10 console.
      staffRoute(
        path: '/staff',
        redirect: (c, s) => staffSignedInRedirect(c, s),
        builder: (_, _) => const StaffDashboardScreen(),
      ),
      staffRoute(
        path: '/staff/moderation',
        redirect: (c, s) => staffSignedInRedirect(c, s),
        builder: (_, s) =>
            StaffModerationScreen(initialTab: s.uri.queryParameters['tab']),
      ),
      staffRoute(
        path: '/staff/issues/:id',
        redirect: (c, s) => staffSignedInRedirect(c, s),
        builder: (_, s) => StaffIssueScreen(id: s.pathParameters['id']!),
      ),
      staffRoute(
        path: '/staff/users',
        redirect: (c, s) => staffSignedInRedirect(c, s),
        builder: (_, _) => const StaffUsersScreen(),
      ),
      staffRoute(
        path: '/staff/categories',
        redirect: (c, s) => staffSignedInRedirect(c, s),
        builder: (_, _) => const StaffCategoriesScreen(),
      ),
      staffRoute(
        path: '/staff/settings',
        redirect: (c, s) => staffSignedInRedirect(c, s),
        builder: (_, _) => const StaffSettingsScreen(),
      ),
      staffRoute(
        path: '/staff/exports',
        redirect: (c, s) => staffSignedInRedirect(c, s),
        builder: (_, _) => const StaffExportsScreen(),
      ),
      staffRoute(
        path: '/staff/forbidden',
        redirect: (c, s) => staffSignedInRedirect(c, s),
        builder: (_, _) => const StaffForbiddenView(),
      ),
      // TASK-08 alerts.
      staffRoute(
        path: '/staff/alerts',
        redirect: (c, s) => staffSignedInRedirect(c, s),
        builder: (_, _) => const StaffAlertsListScreen(),
      ),
      staffRoute(
        path: '/staff/alerts/new',
        redirect: (c, s) => staffSignedInRedirect(c, s),
        builder: (_, _) => const StaffAlertComposerScreen(),
      ),
      staffRoute(
        path: '/staff/alerts/:id',
        redirect: (c, s) => staffSignedInRedirect(c, s),
        builder: (_, s) => StaffAlertDetailScreen(id: s.pathParameters['id']!),
      ),
      staffRoute(
        path: '/staff/alerts/:id/edit',
        redirect: (c, s) => staffSignedInRedirect(c, s),
        builder: (_, s) => StaffAlertEditScreen(id: s.pathParameters['id']!),
      ),
      // TASK-12 services, initiatives and tips.
      ...staffContentRoutes,
      // TASK-11 representative console and claim review.
      staffRoute(
        path: '/staff/ward',
        redirect: (c, s) => staffSignedInRedirect(c, s),
        builder: (_, _) => const WardDashboardScreen(),
      ),
      staffRoute(
        path: '/staff/ward/issues',
        redirect: (c, s) => staffSignedInRedirect(c, s),
        builder: (_, _) => const WardIssuesScreen(),
      ),
      staffRoute(
        path: '/staff/messages',
        redirect: (c, s) => staffSignedInRedirect(c, s),
        builder: (_, _) => const RepMessagesScreen(),
      ),
      staffRoute(
        path: '/staff/messages/:id',
        redirect: (c, s) => staffSignedInRedirect(c, s),
        builder: (_, s) => RepMessageDetailScreen(id: s.pathParameters['id']!),
      ),
      staffRoute(
        path: '/staff/claims',
        redirect: (c, s) => staffSignedInRedirect(c, s),
        builder: (_, _) => const StaffClaimsScreen(),
      ),
      staffRoute(
        path: '/staff/claims/:id',
        redirect: (c, s) => staffSignedInRedirect(c, s),
        builder: (_, s) => StaffClaimDetailScreen(id: s.pathParameters['id']!),
      ),
    ],
  ),
];
