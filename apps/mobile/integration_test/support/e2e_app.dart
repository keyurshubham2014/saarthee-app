// The full Saarthee app (router, shell, real API client) signed in as one
// citizen, with only the camera/GPS, push and haptics faked (TASK-14 §5.6:
// fixture photo + fixed coordinates; real camera covered by M-14-08).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/app.dart';
import 'package:saarthee/core/capture/evidence_capture.dart';
import 'package:saarthee/core/map/civic_map.dart';
import 'package:saarthee/core/motion/haptics.dart';
import 'package:saarthee/core/push/push_messaging.dart';
import 'package:saarthee/core/settings/app_settings.dart';
import 'package:saarthee/core/settings/preference_sync.dart';
import 'package:saarthee/features/auth/data/auth_gateway.dart';
import 'package:saarthee/features/auth/data/secure_store.dart';
import 'package:saarthee/features/report/application/report_draft_controller.dart';
import 'package:saarthee/router/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test/auth/fakes.dart';
import '../../test/helpers/app.dart';
import '../../test/helpers/fake_haptics.dart';
import '../../test/report/report_fakes.dart';
import 'verify_flow.dart';

/// Pumps `SaartheeApp` as the citizen holding [token] (a real Saarthee
/// access token from `signIn`), onboarded, with the fake camera returning a
/// fixture JPEG at [fix]. Does not `pumpAndSettle` (shimmer / live data);
/// waits for the shell's bottom navigation instead. Returns the container.
Future<ProviderContainer> pumpCitizenApp(
  WidgetTester t, {
  required String token,
  required Fix fix,
  String language = 'en',
}) async {
  SharedPreferences.setMockInitialValues(onboardedPrefs(language: language));
  final prefs = await SharedPreferences.getInstance();
  final store = MemorySecureStore();
  store.values[SecureKeys.sessionToken] = token;
  final dir = Directory.systemTemp.createTempSync('e2e-report-photos');
  // A fresh tree per citizen: drop the previous app (and its session).
  await t.pumpWidget(const SizedBox.shrink());
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        saartheeHapticsProvider.overrideWithValue(FakeSaartheeHaptics()),
        preferenceSyncProvider.overrideWithValue(FakePreferenceSync()),
        authGatewayProvider.overrideWithValue(FakeAuthGateway()),
        secureStoreProvider.overrideWithValue(store),
        pushMessagingProvider.overrideWithValue(LocalOnlyPushMessaging()),
        evidenceCaptureProvider.overrideWithValue(
          FakeEvidenceCapture(fix: fix),
        ),
        mapTilesEnabledProvider.overrideWithValue(false),
        reportPhotoDirProvider.overrideWith((ref) async => dir),
      ],
      child: const SaartheeApp(showLaunch: false),
    ),
  );
  await waitFor(t, find.byKey(const Key('nav.0')));
  return ProviderScope.containerOf(t.element(find.byType(SaartheeApp)));
}

/// Navigates the app's router to [location] (deep link, as a push would).
Future<void> goTo(WidgetTester t, ProviderContainer c, String location) async {
  c.read(appRouterProvider).go(location);
  await t.pump();
}
