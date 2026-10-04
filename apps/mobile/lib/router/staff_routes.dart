import 'package:go_router/go_router.dart';

import '../features/staff/alerts/presentation/staff_alert_composer_screen.dart';
import '../features/staff/alerts/presentation/staff_alert_detail_screen.dart';
import '../features/staff/alerts/presentation/staff_alerts_list_screen.dart';
import 'route_helpers.dart';

/// Staff app routes (`/staff/...`). TASK-10 owns the staff shell and side
/// navigation and mounts these; until then each screen wraps itself in
/// `StaffPageScaffold`. Role checks here are UX only (the API enforces them).
/// Append-only: each task adds a `// TASK-NN` block.
final List<RouteBase> staffRoutes = <RouteBase>[
  // TASK-08 alerts.
  saartheeRoute(
    path: '/staff/alerts',
    builder: (_, _) => const StaffAlertsListScreen(),
  ),
  saartheeRoute(
    path: '/staff/alerts/new',
    builder: (_, _) => const StaffAlertComposerScreen(),
  ),
  saartheeRoute(
    path: '/staff/alerts/:id',
    builder: (_, s) => StaffAlertDetailScreen(id: s.pathParameters['id']!),
  ),
  saartheeRoute(
    path: '/staff/alerts/:id/edit',
    builder: (_, s) => StaffAlertEditScreen(id: s.pathParameters['id']!),
  ),
];
