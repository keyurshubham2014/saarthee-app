import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/motion/transitions.dart';
import '../features/auth/application/ensure_signed_in.dart';
import '../features/home/presentation/about_screen.dart';
import '../features/me/presentation/me_screen.dart';
import '../features/me/presentation/privacy_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/shell/my_ward_screen.dart';
import '../features/shell/shell_scaffold.dart';
import '../features/report/report_routes.dart';
import '../features/discovery/discovery_routes.dart';
import '../features/discovery/presentation/map/map_tab_screen.dart';
import '../features/ward/ward_routes.dart';
import '../features/rep_claim/rep_claim_routes.dart';
import 'app_router.dart' show rootNavigatorKey;
import '../features/alerts/data/alert_models.dart';
import '../features/alerts/presentation/alert_detail_screen.dart';
import '../features/alerts/presentation/alert_settings_screen.dart';
import '../features/alerts/presentation/alerts_tab_screen.dart' as alerts;
import '../features/inbox/presentation/inbox_screen.dart';
import 'route_helpers.dart';

// ---------------------------------------------------------------------------
// Five-tab citizen shell (TASK-03). Each branch has its own navigator, so a
// tab keeps its scroll and pushed pages.
//
// FEATURE CONVENTION (append-only, see apps/mobile/README.md):
// - A feature adds child routes for a tab by appending to that tab's list
//   below, inside a block headed `// TASK-NN <feature>`; it never edits
//   another task's block.
// - A feature that replaces a tab body (P-04 Map, P-05 Report, P-06 Alerts)
//   changes only that branch's root `builder` line.
// - Full-screen routes above the shell go in `rootFeatureRoutes`
//   (app_router.dart).
// ---------------------------------------------------------------------------

final homeNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'home');
final mapNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'map');
final reportNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'report');
final alertsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'alerts');
final wardNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'ward');

/// Child routes under `/` (Home).
final List<RouteBase> homeChildRoutes = <RouteBase>[
  // TASK-07 discovery: issue detail, feed.
];

/// Child routes under `/map`.
final List<RouteBase> mapChildRoutes = <RouteBase>[
  // TASK-07 discovery.
];

/// Child routes under `/report`.
final List<RouteBase> reportChildRoutes = <RouteBase>[
  // TASK-05 report steps.
  ...reportRoutes(rootNavigatorKey),
];

/// Child routes under `/alerts`.
final List<RouteBase> alertsChildRoutes = <RouteBase>[
  // TASK-08 alerts.
  saartheeRoute(
    path: 'settings',
    builder: (_, state) => AlertSettingsScreen(
      highlightType: state.uri.queryParameters['type'] == null
          ? null
          : AlertType.parse(state.uri.queryParameters['type']),
    ),
  ),
  saartheeRoute(
    path: ':id',
    builder: (_, state) => AlertDetailScreen(id: state.pathParameters['id']!),
  ),
];

/// Child routes under `/ward`.
final List<RouteBase> wardChildRoutes = <RouteBase>[
  // TASK-09 representatives, TASK-12 services.
  // TASK-09 my-ward: /ward/:id, /ward/:id/scorecard.
  ...wardFeatureChildRoutes,
];

/// Extra top-level routes inside the My Ward branch (`/me/...`).
final List<RouteBase> meRoutes = <RouteBase>[
  saartheeRoute(
    path: '/me/settings',
    builder: (_, _) => const SettingsScreen(),
  ),
  saartheeRoute(path: '/about', builder: (_, _) => const AboutScreen()),
  // TASK-04 accounts: /me, sign-in, privacy.
  saartheeRoute(path: '/me', builder: (_, _) => const MeScreen()),
  saartheeRoute(
    path: '/me/privacy',
    redirect: requireAccountRedirect,
    builder: (_, _) => const PrivacyScreen(),
  ),
  // TASK-11 representative claim steps and /me/messages (before TASK-09's
  // /representatives/:id so the longer paths match first).
  ...repClaimRoutes,
  // TASK-09 representatives: profile and message form.
  ...representativeRoutes,
  // TASK-08 inbox.
  saartheeRoute(
    path: '/me/notifications',
    builder: (_, _) => const InboxScreen(),
  ),
  // TASK-07 discovery: My reports, Following.
  ...discoveryMeRoutes,
];

StatefulShellRoute buildCitizenShell() => StatefulShellRoute(
  builder: (context, state, shell) => ShellScaffold(navigationShell: shell),
  navigatorContainerBuilder: (context, shell, children) =>
      FadeThroughShellContainer(
        currentIndex: shell.currentIndex,
        children: children,
      ),
  branches: [
    StatefulShellBranch(
      navigatorKey: homeNavigatorKey,
      routes: [
        saartheeRoute(
          path: '/',
          builder: (_, _) => const HomeScreen(),
          routes: homeChildRoutes,
        ),
      ],
    ),
    StatefulShellBranch(
      navigatorKey: mapNavigatorKey,
      routes: [
        saartheeRoute(
          path: '/map',
          builder: (_, _) => const MapTabScreen(),
          routes: mapChildRoutes,
        ),
      ],
    ),
    StatefulShellBranch(
      navigatorKey: reportNavigatorKey,
      routes: [
        saartheeRoute(
          path: '/report',
          builder: buildReportTab,
          routes: reportChildRoutes,
        ),
      ],
    ),
    StatefulShellBranch(
      navigatorKey: alertsNavigatorKey,
      routes: [
        saartheeRoute(
          path: '/alerts',
          builder: (_, _) => const alerts.AlertsTabScreen(),
          routes: alertsChildRoutes,
        ),
      ],
    ),
    StatefulShellBranch(
      navigatorKey: wardNavigatorKey,
      routes: [
        saartheeRoute(
          path: '/ward',
          builder: (_, _) => const MyWardScreen(),
          routes: wardChildRoutes,
        ),
        ...meRoutes,
      ],
    ),
  ],
);
