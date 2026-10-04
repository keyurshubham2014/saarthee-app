import 'package:go_router/go_router.dart';

import '../../auth/application/ensure_signed_in.dart';
import '../shell/staff_motion.dart';
import 'presentation/staff_attendance_screen.dart';
import 'presentation/staff_initiative_form_screen.dart';
import 'presentation/staff_initiatives_screen.dart';
import 'presentation/staff_service_form_screen.dart';
import 'presentation/staff_services_screen.dart';
import 'presentation/staff_tips_screen.dart';

Map<String, dynamic>? _row(GoRouterState s) =>
    s.extra is Map<String, dynamic> ? s.extra! as Map<String, dynamic> : null;

/// TASK-12 staff content screens, mounted in TASK-10's `/staff` shell (side
/// navigation, `short` fades) and sign-in-guarded (contract in TASK-12
/// §5.4). Editing an item opens from its list row (the row is passed as
/// `extra`).
final List<RouteBase> staffContentRoutes = <RouteBase>[
  staffRoute(
    path: '/staff/services',
    redirect: requireAccountRedirect,
    builder: (_, _) => const StaffServicesScreen(),
  ),
  staffRoute(
    path: '/staff/services/new',
    redirect: requireAccountRedirect,
    builder: (_, _) => const StaffServiceFormScreen(),
  ),
  staffRoute(
    path: '/staff/services/:id',
    redirect: requireAccountRedirect,
    builder: (_, s) => StaffServiceFormScreen(existing: _row(s)),
  ),
  staffRoute(
    path: '/staff/initiatives',
    redirect: requireAccountRedirect,
    builder: (_, _) => const StaffInitiativesScreen(),
  ),
  staffRoute(
    path: '/staff/initiatives/new',
    redirect: requireAccountRedirect,
    builder: (_, _) => const StaffInitiativeFormScreen(),
  ),
  staffRoute(
    path: '/staff/initiatives/:id',
    redirect: requireAccountRedirect,
    builder: (_, s) => StaffInitiativeFormScreen(existing: _row(s)),
  ),
  staffRoute(
    path: '/staff/initiatives/:id/attendance',
    redirect: requireAccountRedirect,
    builder: (_, s) => StaffAttendanceScreen(
      id: s.pathParameters['id']!,
      startsAt: DateTime.tryParse('${_row(s)?['startsAt'] ?? ''}'),
    ),
  ),
  staffRoute(
    path: '/staff/tips',
    redirect: requireAccountRedirect,
    builder: (_, _) => const StaffTipsScreen(),
  ),
  staffRoute(
    path: '/staff/tips/new',
    redirect: requireAccountRedirect,
    builder: (_, _) => const StaffTipFormScreen(),
  ),
  staffRoute(
    path: '/staff/tips/:id',
    redirect: requireAccountRedirect,
    builder: (_, s) => StaffTipFormScreen(existing: _row(s)),
  ),
];
