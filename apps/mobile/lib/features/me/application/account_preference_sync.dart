import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/push/push_registrar.dart';
import '../../../core/settings/preference_sync.dart';
import '../../../core/wards/ward.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/data/account_api.dart';
import '../../auth/data/account_models.dart';

/// TASK-04 binding of the TASK-03 [PreferenceSync] port (AC-7): when signed
/// in, the new language / home ward is sent once with `PATCH /me`; in every
/// case the FCM topics are switched (old unsubscribed, new subscribed) and
/// `POST /devices` is re-sent with `language` and `topics`.
class AccountPreferenceSync implements PreferenceSync {
  AccountPreferenceSync(this._ref);

  final Ref _ref;

  Future<void> _patch(Map<String, Object?> fields) async {
    final session = _ref.read(sessionProvider);
    if (!session.signedIn) return;
    try {
      final me = await _ref.read(accountApiProvider).patchMe(fields);
      _ref.read(sessionProvider.notifier).setMe(me);
    } catch (_) {
      // Offline: the device keeps the local choice; the account catches up on
      // the next change (the server is never ahead of the device here).
    }
  }

  @override
  Future<void> languageChanged(String languageCode) async {
    await _patch({'language': languageCode});
    await syncPush(_ref);
  }

  @override
  Future<void> homeWardChanged(Ward? ward) async {
    await _patch({'homeWardId': ward?.id});
    await syncPush(_ref);
  }
}

/// Topic + device sync, honouring a withdrawn notifications consent.
Future<void> syncPush(Ref ref) {
  final me = ref.read(sessionProvider).me;
  final withdrawn =
      me != null &&
      me.consents.any(
        (c) => c.purpose == ConsentPurpose.notifications && !c.granted,
      );
  return ref.read(pushRegistrarProvider).sync(allowed: !withdrawn);
}

final accountPreferenceSyncProvider = Provider<PreferenceSync>(
  AccountPreferenceSync.new,
);

/// App start (after onboarding): restore the session, then register the
/// device and its topics (`POST /devices`).
final pushStartupProvider = FutureProvider<void>((ref) async {
  await ref.read(pushRegistrarProvider).countLaunch();
  await ref.read(sessionProvider.notifier).ready;
  await syncPush(ref);
});
