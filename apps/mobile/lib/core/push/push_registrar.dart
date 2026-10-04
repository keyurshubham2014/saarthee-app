import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../config/app_config.dart';
import '../settings/app_settings.dart';
import '../settings/locale_controller.dart';
import '../wards/ward_providers.dart';
import 'push_messaging.dart';

/// Keeps FCM topic subscriptions and the `devices` row in step with the
/// device language, home ward and the citizen's choice (TASK-04 §5.4,
/// REQ-F-010). `POST /devices` carries the session when signed in (session
/// interceptor), so the install is linked to the account.
class PushRegistrar {
  PushRegistrar(this._ref);

  final Ref _ref;

  static const enabledKey = 'saarthee.push.enabled';
  static const topicsKey = 'saarthee.push.topics';
  static const promptDismissedKey = 'saarthee.push.promptDismissed';

  PushMessaging get _messaging => _ref.read(pushMessagingProvider);
  SharedPreferences get _prefs => _ref.read(sharedPreferencesProvider);

  /// The citizen turned notifications on (soft prompt or Privacy).
  bool get enabled => _prefs.getBool(enabledKey) ?? false;

  bool get promptDismissed => _prefs.getBool(promptDismissedKey) ?? false;

  /// Topics this install is subscribed to.
  List<String> get topics =>
      _prefs.getStringList(topicsKey) ?? const <String>[];

  Future<void> dismissPrompt() => _prefs.setBool(promptDismissedKey, true);

  static const launchesKey = 'saarthee.push.launches';

  /// App starts after onboarding; the Home soft prompt waits for the second
  /// (never at first launch, TASK-04 §5.4).
  int get launches => _prefs.getInt(launchesKey) ?? 0;

  Future<void> countLaunch() => _prefs.setInt(launchesKey, launches + 1);

  /// Whether Home should offer the soft prompt.
  bool get shouldPrompt => launches >= 2 && !enabled && !promptDismissed;

  /// Asks for the OS permission; on success turns push on and subscribes.
  Future<bool> enable() async {
    final granted = await _messaging.requestPermission();
    await _prefs.setBool(enabledKey, granted);
    await _prefs.setBool(promptDismissedKey, true);
    await sync();
    return granted;
  }

  /// Turns push off on this device (unsubscribes every topic).
  Future<void> disable() async {
    await _prefs.setBool(enabledKey, false);
    await sync();
  }

  /// Re-computes topics: unsubscribes the old ones, subscribes the new ones
  /// and re-posts the device. [allowed] is false when the account withdrew
  /// the notifications consent. Network failures are ignored (next start
  /// retries).
  Future<void> sync({bool allowed = true}) async {
    final language = _ref.read(localeProvider).languageCode;
    final ward = _ref.read(homeWardProvider);
    final want = enabled && allowed
        ? pushTopicsFor(language: language, wardNumber: ward?.number)
        : const <String>[];
    final have = topics;
    for (final t in have.where((t) => !want.contains(t))) {
      await _messaging.unsubscribe(t);
    }
    for (final t in want.where((t) => !have.contains(t))) {
      await _messaging.subscribe(t);
    }
    await _prefs.setStringList(topicsKey, want);
    final token = enabled && allowed ? await _messaging.token() : null;
    try {
      await _ref
          .read(apiClientProvider)
          .postJson(
            '/devices',
            body: {
              'installId': _ref.read(appSettingsProvider).installId,
              'fcmToken': token,
              'platform': appPlatformName(),
              'appVersion': AppConfig.appVersion,
              'language': language == 'en' ? 'en' : 'gu',
              'topics': want,
            },
          );
    } catch (_) {
      // Offline or rate limited: registration is retried on the next sync.
    }
  }
}

final pushRegistrarProvider = Provider<PushRegistrar>(PushRegistrar.new);
