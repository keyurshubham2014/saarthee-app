import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_settings.dart';

/// In-app "Animations" switch, persisted as `v2.animationsEnabled`
/// (default on). Device-only, never synced to the account.
class MotionPreferenceNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref
          .watch(sharedPreferencesProvider)
          .getBool(PrefKeys.animationsEnabled) ??
      true;

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    await ref
        .read(sharedPreferencesProvider)
        .setBool(PrefKeys.animationsEnabled, enabled);
  }
}

final motionPreferenceProvider =
    NotifierProvider<MotionPreferenceNotifier, bool>(
      MotionPreferenceNotifier.new,
    );

/// The system "Remove animations" flag (`MediaQuery.disableAnimations`),
/// kept in sync by `MotionScope`.
class SystemDisableAnimationsNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

final systemDisableAnimationsProvider =
    NotifierProvider<SystemDisableAnimationsNotifier, bool>(
      SystemDisableAnimationsNotifier.new,
    );

/// Single source of truth for reduced motion: the system flag **or** the
/// in-app switch turned off (DS §6 rules). Widgets and features read this
/// (or `SaartheeMotion.of(context)`), never `MediaQuery` directly.
final reducedMotionProvider = Provider<bool>(
  (ref) =>
      ref.watch(systemDisableAnimationsProvider) ||
      !ref.watch(motionPreferenceProvider),
);
