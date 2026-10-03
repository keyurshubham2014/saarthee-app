import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../core/motion/transitions.dart';

/// A `GoRoute` whose page uses the shared-axis push motion (DS §6). Every
/// citizen route should be built with this.
GoRoute saartheeRoute({
  required String path,
  required Widget Function(BuildContext context, GoRouterState state) builder,
  List<RouteBase> routes = const <RouteBase>[],
  GlobalKey<NavigatorState>? parentNavigatorKey,
  GoRouterRedirect? redirect,
  String? name,
}) => GoRoute(
  path: path,
  name: name,
  parentNavigatorKey: parentNavigatorKey,
  redirect: redirect,
  routes: routes,
  pageBuilder: (context, state) => saartheePage<void>(
    context: context,
    state: state,
    child: builder(context, state),
  ),
);
