import 'package:go_router/go_router.dart';

import '../../../router/route_helpers.dart';
import '../../auth/application/ensure_signed_in.dart';
import 'presentation/staff_attendance_screen.dart';
import 'presentation/staff_initiative_form_screen.dart';
import 'presentation/staff_initiatives_screen.dart';
import 'presentation/staff_service_form_screen.dart';
import 'presentation/staff_services_screen.dart';
import 'presentation/staff_tips_screen.dart';

Map<String, dynamic>? _row(GoRouterState s) =>
    s.extra is Map<String, dynamic> ? s.extra! as Map<String, dynamic> : null;

/// TASK-12 staff content screens: standalone, sign-in- and role-guarded
/// routes until TASK-10's `/staff` shell adds them to its side navigation
/// (contract in TASK-12 §5.4). Editing an item opens from its list row
/// (the row is passed as `extra`).
final List<RouteBase> staffContentRoutes = <RouteBase>[
  saartheeRoute(
    path: '/staff/services',
    redirect: requireAccountRedirect,
    builder: (_, _) => const StaffServicesScreen(),
  ),
  saartheeRoute(
    path: '/staff/services/new',
    redirect: requireAccountRedirect,
    builder: (_, _) => const StaffServiceFormScreen(),
  ),
  saartheeRoute(
    path: '/staff/services/:id',
    redirect: requireAccountRedirect,
    builder: (_, s) => StaffServiceFormScreen(existing: _row(s)),
  ),
  saartheeRoute(
    path: '/staff/initiatives',
    redirect: requireAccountRedirect,
    builder: (_, _) => const StaffInitiativesScreen(),
  ),
  saartheeRoute(
    path: '/staff/initiatives/new',
    redirect: requireAccountRedirect,
    builder: (_, _) => const StaffInitiativeFormScreen(),
  ),
  saartheeRoute(
    path: '/staff/initiatives/:id',
    redirect: requireAccountRedirect,
    builder: (_, s) => StaffInitiativeFormScreen(existing: _row(s)),
  ),
  saartheeRoute(
    path: '/staff/initiatives/:id/attendance',
    redirect: requireAccountRedirect,
    builder: (_, s) => StaffAttendanceScreen(
      id: s.pathParameters['id']!,
      startsAt: DateTime.tryParse('${_row(s)?['startsAt'] ?? ''}'),
    ),
  ),
  saartheeRoute(
    path: '/staff/tips',
    redirect: requireAccountRedirect,
    builder: (_, _) => const StaffTipsScreen(),
  ),
  saartheeRoute(
    path: '/staff/tips/new',
    redirect: requireAccountRedirect,
    builder: (_, _) => const StaffTipFormScreen(),
  ),
  saartheeRoute(
    path: '/staff/tips/:id',
    redirect: requireAccountRedirect,
    builder: (_, s) => StaffTipFormScreen(existing: _row(s)),
  ),
];
