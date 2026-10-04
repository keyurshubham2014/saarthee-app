import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/l10n/app_localizations.dart';
import 'package:saarthee/core/motion/haptics.dart';
import 'package:saarthee/core/settings/app_settings.dart';
import 'package:saarthee/core/settings/motion_preference.dart';
import 'package:saarthee/core/theme/app_theme.dart';
import 'package:saarthee/core/theme/motion.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_haptics.dart';

/// Fresh in-memory prefs.
Future<SharedPreferences> testPrefs([
  Map<String, Object> values = const {},
]) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

/// Pumps [child] inside a themed, localized `MaterialApp` under a
/// `ProviderScope` and `MotionScope`. [reduced] forces
/// `reducedMotionProvider`; [disableAnimations] sets the system flag
/// through `MediaQuery` instead. Returns the container for assertions.
Future<ProviderContainer> pumpMotion(
  WidgetTester tester,
  Widget child, {
  bool? reduced,
  bool disableAnimations = false,
  Locale locale = const Locale('en'),
  ThemeMode themeMode = ThemeMode.light,
  double textScale = 1,
  FakeSaartheeHaptics? haptics,
  SharedPreferences? prefs,
  List overrides = const [],
}) async {
  final p = prefs ?? await testPrefs();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(p),
      saartheeHapticsProvider.overrideWithValue(
        haptics ?? FakeSaartheeHaptics(),
      ),
      if (reduced != null) reducedMotionProvider.overrideWithValue(reduced),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: locale,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: disableAnimations,
            textScaler: TextScaler.linear(textScale),
          ),
          child: MotionScope(child: app!),
        ),
        home: Scaffold(body: child),
      ),
    ),
  );
  return container;
}
