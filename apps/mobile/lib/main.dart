import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/errors/global_error.dart';
import 'core/settings/app_settings.dart';
import 'core/settings/preference_sync.dart';
import 'features/me/application/account_preference_sync.dart';
import 'router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.assertValid();
  registerFontLicenses();
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      // TASK-04: language / home ward reach the account and push topics.
      preferenceSyncProvider.overrideWith(AccountPreferenceSync.new),
    ],
    // Screens retry explicitly; no automatic provider retries.
    retry: (_, _) => null,
  );

  // Global error handling (02 §9.1): logged in debug; in release, the
  // generic "Something went wrong" screen. Local storage is never touched.
  void showGlobalError() {
    if (kDebugMode) return;
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;
    container.read(appRouterProvider).go('/error');
  }

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    showGlobalError();
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught error: ${error.runtimeType}');
    showGlobalError();
    return true;
  };
  if (!kDebugMode) {
    ErrorWidget.builder = (_) => GlobalErrorView(
      onGoHome: () => container.read(appRouterProvider).go('/'),
    );
  }

  // TASK-04: register the device and its topics once onboarding is done.
  if (container.read(appSettingsProvider).onboardingDone) {
    unawaited(container.read(pushStartupProvider.future));
  }

  runApp(
    UncontrolledProviderScope(container: container, child: const SaartheeApp()),
  );
}

/// Bundled font licences (SIL OFL 1.1) shown on the licences page.
void registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final (family, asset) in const [
      ('Baloo Bhai 2', 'assets/fonts/BalooBhai2-OFL.txt'),
      ('Mukta Vaani', 'assets/fonts/MuktaVaani-OFL.txt'),
    ]) {
      yield LicenseEntryWithLineBreaks([
        family,
      ], await rootBundle.loadString(asset));
    }
  });
}
