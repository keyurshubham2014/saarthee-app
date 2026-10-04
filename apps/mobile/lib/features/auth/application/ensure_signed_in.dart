import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'phone_sign_in.dart';
import 'session_controller.dart';

export 'phone_sign_in.dart' show SignInReason;

/// "Sign in when needed" (D6, TASK-04 §5.4). Returns `true` at once when a
/// session exists; otherwise pushes `/sign-in?from=…` above the current
/// screen (its state stays intact) and returns whether sign-in succeeded,
/// so the calling action can continue:
///
/// ```dart
/// if (await ensureSignedIn(context, ref, reason: SignInReason.meToo)) send();
/// ```
Future<bool> ensureSignedIn(
  BuildContext context,
  WidgetRef ref, {
  required SignInReason reason,
}) async {
  await ref.read(sessionProvider.notifier).ready;
  if (ref.read(sessionProvider).signedIn) return true;
  if (!context.mounted) return false;
  final router = GoRouter.of(context);
  final from = router.routerDelegate.currentConfiguration.uri.toString();
  final ok = await router.push<bool>(signInLocation(from: from, reason: reason));
  return ok == true && ref.read(sessionProvider).signedIn;
}

/// `/sign-in?from=<in-app path>&reason=<reason>`.
String signInLocation({required String from, SignInReason? reason}) => Uri(
  path: '/sign-in',
  queryParameters: {
    'from': safeReturnPath(from),
    if (reason != null) 'reason': reason.name,
  },
).toString();

/// `from` must be an in-app path (starts with `/`, no scheme, not `//`);
/// anything else returns to Home.
String safeReturnPath(String? from) {
  if (from == null || !from.startsWith('/') || from.startsWith('//')) {
    return '/';
  }
  if (from.contains('://') || from.contains('\\')) return '/';
  if (from.startsWith('/sign-in')) return '/';
  return from;
}

/// Router redirect for routes that need an account (deep links): signed-out
/// visitors go to `/sign-in?from=<that route>`. While the stored session is
/// still loading at start-up the route is allowed (its screen re-checks).
String? requireAccountRedirect(BuildContext context, GoRouterState state) {
  final container = ProviderScope.containerOf(context, listen: false);
  final session = container.read(sessionProvider);
  if (!session.restored || session.signedIn) return null;
  return signInLocation(
    from: state.uri.toString(),
    reason: SignInReason.profile,
  );
}

/// Ends the sign-in flow: pops back to the caller with [ok], or — when the
/// flow was opened by a redirect and there is nothing to pop — goes to
/// [from] (success) or Home.
void finishSignIn(BuildContext context, bool ok, {String? from}) {
  if (context.canPop()) {
    context.pop(ok);
  } else {
    context.go(ok ? safeReturnPath(from) : '/');
  }
}
