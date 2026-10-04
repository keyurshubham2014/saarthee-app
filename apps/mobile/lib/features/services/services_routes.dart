import 'package:go_router/go_router.dart';

import '../../router/route_helpers.dart';
import '../initiatives/presentation/initiative_detail_screen.dart';
import '../initiatives/presentation/initiatives_list_screen.dart';
import 'presentation/service_detail_screen.dart';
import 'presentation/services_list_screen.dart';

/// TASK-12 full-screen citizen routes (root navigator, above the shell).
/// `/initiatives/:id` is also a push target (TASK-04 allow-list).
final List<RouteBase> servicesRoutes = <RouteBase>[
  saartheeRoute(
    path: '/services',
    builder: (_, _) => const ServicesListScreen(),
  ),
  saartheeRoute(
    path: '/services/:slug',
    builder: (_, state) =>
        ServiceDetailScreen(slug: state.pathParameters['slug']!),
  ),
  saartheeRoute(
    path: '/initiatives',
    builder: (_, _) => const InitiativesListScreen(),
  ),
  saartheeRoute(
    path: '/initiatives/:id',
    builder: (_, state) =>
        InitiativeDetailScreen(id: state.pathParameters['id']!),
  ),
];
