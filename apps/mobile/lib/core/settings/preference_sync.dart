import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../wards/ward.dart';

/// Port for syncing the language and home ward to the citizen's account.
/// TASK-04 overrides [preferenceSyncProvider] to send `PATCH /me` when signed
/// in and to re-subscribe FCM topics. The Animations switch is device-only.
abstract interface class PreferenceSync {
  Future<void> languageChanged(String languageCode);
  Future<void> homeWardChanged(Ward? ward);
}

/// Default binding: no account yet, nothing to sync.
class NoopPreferenceSync implements PreferenceSync {
  const NoopPreferenceSync();

  @override
  Future<void> languageChanged(String languageCode) async {}

  @override
  Future<void> homeWardChanged(Ward? ward) async {}
}

final preferenceSyncProvider = Provider<PreferenceSync>(
  (ref) => const NoopPreferenceSync(),
);
