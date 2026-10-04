import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/session_controller.dart';
import '../../auth/data/account_models.dart';
import '../../me/application/me_controller.dart';

/// The `share_with_representatives` consent seen from the message form
/// (TASK-09 §5.4: first send without consent → consent sheet → continue).
/// Tests override [relayConsentProvider].
abstract interface class RelayConsent {
  bool get granted;
  Future<void> grant();
}

class SessionRelayConsent implements RelayConsent {
  SessionRelayConsent(this._ref);

  final Ref _ref;

  @override
  bool get granted =>
      _ref
          .read(sessionProvider)
          .me
          ?.consentGranted(ConsentPurpose.shareWithRepresentatives) ??
      false;

  @override
  Future<void> grant() => _ref
      .read(meActionsProvider)
      .setConsent(ConsentPurpose.shareWithRepresentatives, true);
}

final relayConsentProvider = Provider<RelayConsent>(SessionRelayConsent.new);
