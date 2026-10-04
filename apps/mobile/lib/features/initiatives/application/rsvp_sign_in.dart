import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/ensure_signed_in.dart';

/// "Sign in when needed" before an RSVP (TASK-04 `ensureSignedIn`, reason
/// `rsvp`). A provider so widget tests can record the call order.
typedef RsvpSignIn = Future<bool> Function(BuildContext context, WidgetRef ref);

final rsvpSignInProvider = Provider<RsvpSignIn>(
  (ref) =>
      (context, widgetRef) =>
          ensureSignedIn(context, widgetRef, reason: SignInReason.rsvp),
);
