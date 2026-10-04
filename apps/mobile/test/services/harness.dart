import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:saarthee/core/l10n/app_localizations.dart';
import 'package:saarthee/core/motion/haptics.dart';
import 'package:saarthee/core/settings/app_settings.dart';
import 'package:saarthee/core/settings/motion_preference.dart';
import 'package:saarthee/core/settings/preference_sync.dart';
import 'package:saarthee/core/theme/app_theme.dart';
import 'package:saarthee/core/theme/motion.dart';
import 'package:saarthee/core/wards/ward.dart';
import 'package:saarthee/core/wards/wards_repository.dart';
import 'package:saarthee/features/initiatives/application/rsvp_sign_in.dart';
import 'package:saarthee/features/initiatives/data/initiatives_repository.dart';
import 'package:saarthee/features/services/application/external_links.dart';
import 'package:saarthee/features/services/data/services_repository.dart';
import 'package:saarthee/features/services/services_routes.dart';
import 'package:saarthee/features/staff/content/presentation/staff_gate.dart';
import 'package:saarthee/features/staff/content/staff_content_routes.dart';

import '../helpers/app.dart' show FakePreferenceSync;
import '../helpers/fake_haptics.dart';
import '../helpers/fake_wards.dart';
import '../helpers/motion.dart' show testPrefs;
import 'fakes.dart';

/// Records external launches (URL, mode).
class LaunchRecorder {
  final List<(Uri, LaunchMode)> calls = [];
  bool result = true;

  Future<bool> call(Uri uri, LaunchMode mode) async {
    calls.add((uri, mode));
    return result;
  }
}

/// Records sign-in requests; answers [allow].
class SignInRecorder {
  SignInRecorder(this.log, {this.allow = true});

  final List<String> log;
  bool allow;

  Future<bool> call(BuildContext context, WidgetRef ref) async {
    log.add('signIn');
    return allow;
  }
}

Map<String, Object> homeWardPrefs(Ward ward) => {
  PrefKeys.homeWard: jsonEncode(ward.toPrefsJson()),
};

/// Pumps the TASK-12 routes (plus a bare `/`) under fakes. Returns the
/// router so tests can navigate.
Future<GoRouter> pumpServices(
  WidgetTester tester, {
  required String location,
  FakeServicesRepository? services,
  FakeInitiativesRepository? initiatives,
  LaunchRecorder? launcher,
  SignInRecorder? signIn,
  FakeSaartheeHaptics? haptics,
  Map<String, Object> prefs = const {},
  String role = 'citizen',
  bool? reduced,
  bool disableAnimations = false,
  Size size = const Size(400, 900),
  Widget home = const SizedBox.shrink(),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final p = await testPrefs({PrefKeys.languageCode: 'en', ...prefs});
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(path: '/', builder: (_, _) => Scaffold(body: home)),
      ...servicesRoutes,
      ...staffContentRoutes,
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      // As in main.dart: failed providers wait for the user's "Try again".
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(p),
        saartheeHapticsProvider.overrideWithValue(haptics ?? FakeSaartheeHaptics()),
        preferenceSyncProvider.overrideWithValue(FakePreferenceSync()),
        wardsRepositoryProvider.overrideWithValue(FakeWardsRepository()),
        servicesRepositoryProvider.overrideWithValue(services ?? FakeServicesRepository()),
        initiativesRepositoryProvider.overrideWithValue(initiatives ?? FakeInitiativesRepository(const [])),
        externalLauncherProvider.overrideWithValue((launcher ?? LaunchRecorder()).call),
        rsvpSignInProvider.overrideWithValue((signIn ?? SignInRecorder([])).call),
        staffRoleProvider.overrideWithValue(role),
        if (reduced != null) reducedMotionProvider.overrideWithValue(reduced),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('en'),
        theme: AppTheme.light(),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
          child: MotionScope(child: app!),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return router;
}
