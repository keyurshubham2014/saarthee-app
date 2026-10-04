import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/app.dart';
import 'package:saarthee/core/motion/haptics.dart';
import 'package:saarthee/core/settings/app_settings.dart';
import 'package:saarthee/core/settings/preference_sync.dart';
import 'package:saarthee/core/wards/ward.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_haptics.dart';
import 'motion.dart';

/// Records `PreferenceSync` calls (TASK-04 replaces the no-op binding).
class FakePreferenceSync implements PreferenceSync {
  final List<String> languages = [];
  final List<Ward?> wards = [];

  @override
  Future<void> languageChanged(String languageCode) async =>
      languages.add(languageCode);

  @override
  Future<void> homeWardChanged(Ward? ward) async => wards.add(ward);
}

/// Prefs for an install that finished onboarding.
Map<String, Object> onboardedPrefs({String language = 'en'}) => {
  PrefKeys.onboardingDone: true,
  PrefKeys.languageCode: language,
};

/// Pumps the full app (router, shell, theme) without the launch gate.
Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
  FakePreferenceSync? sync,
  FakeSaartheeHaptics? haptics,
  List overrides = const [],
  Size size = const Size(400, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final SharedPreferences p = await testPrefs(prefs);
  final overrideList = [
    sharedPreferencesProvider.overrideWithValue(p),
    saartheeHapticsProvider.overrideWithValue(haptics ?? FakeSaartheeHaptics()),
    preferenceSyncProvider.overrideWithValue(sync ?? FakePreferenceSync()),
    ...overrides,
  ];
  // A ProviderScope (not Uncontrolled) is disposed with the tree, which
  // cancels the analytics flush timer before the pending-timer check.
  await tester.pumpWidget(
    ProviderScope(
      overrides: [...overrideList],
      child: const SaartheeApp(showLaunch: false),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(SaartheeApp)));
}
