import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_settings.dart';
import 'preference_sync.dart';

/// Supported app languages, Gujarati first.
const supportedLanguageCodes = <String>['gu', 'en'];

/// Device locale reader (overridable in tests).
final deviceLocaleProvider = Provider<Locale>(
  (ref) => PlatformDispatcher.instance.locale,
);

/// The app locale, persisted as `v2.languageCode`. Absent → the device locale
/// if it is Gujarati, else English (TASK-03 §5.2). Changing it rebuilds the
/// whole app instantly and notifies [PreferenceSync].
class LocaleController extends Notifier<Locale> {
  @override
  Locale build() {
    final stored = ref
        .watch(sharedPreferencesProvider)
        .getString(PrefKeys.languageCode);
    if (stored != null && supportedLanguageCodes.contains(stored)) {
      return Locale(stored);
    }
    return Locale(deviceDefault);
  }

  /// `gu` when the device is Gujarati, else `en`.
  String get deviceDefault =>
      ref.read(deviceLocaleProvider).languageCode == 'gu' ? 'gu' : 'en';

  /// True once the citizen chose a language (onboarding or settings).
  bool get hasChoice => ref
      .read(sharedPreferencesProvider)
      .containsKey(PrefKeys.languageCode);

  Future<void> setLanguage(String code) async {
    if (!supportedLanguageCodes.contains(code)) return;
    final changed = state.languageCode != code || !hasChoice;
    state = Locale(code);
    await ref
        .read(sharedPreferencesProvider)
        .setString(PrefKeys.languageCode, code);
    if (changed) {
      await ref.read(preferenceSyncProvider).languageChanged(code);
    }
  }

  /// "અ" / "A" toggle.
  Future<void> toggle() =>
      setLanguage(state.languageCode == 'gu' ? 'en' : 'gu');
}

final localeProvider = NotifierProvider<LocaleController, Locale>(
  LocaleController.new,
);
