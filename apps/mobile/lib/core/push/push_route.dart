import 'package:go_router/go_router.dart';

/// In-app routes a notification tap may open (TASK-04 §5.4). Anything else
/// — URLs, `//host`, admin paths, unknown screens — opens Home.
final RegExp _allowed = RegExp(
  r'^/(issues|alerts|initiatives|me/notifications)(/[A-Za-z0-9-]+)?$'
  // TASK-06: "Is it fixed? Help check" opens the verify flow.
  r'|^/issues/[A-Za-z0-9-]+/verify$',
);

/// The route to open for a tapped notification's `data.route`.
String safePushRoute(Object? route) {
  if (route is! String) return '/';
  return _allowed.hasMatch(route) ? route : '/';
}

/// Opens the tapped notification's route (foreground, background and
/// terminated taps all come here).
void openPushTap(GoRouter router, Map<String, Object?> data) {
  router.go(safePushRoute(data['route']));
}
