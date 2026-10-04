// I-06-01 (TASK-06 AC-5, AC-12, AC-14): report → acknowledge → mark fixed → a
// neighbour verifies in the app → Verified; and the reopened case (the
// reporter answers "Still not fixed" → Reopened). Real API + Auth Emulator.
// Report and staff steps go through the API (seeded moderator, phone
// +919000000025 by default); the verify flow runs in the app UI with a fake
// camera/GPS fix 30 m from the issue. Run by the integrator:
//   flutter test integration_test/report_verify_test.dart -d emulator-5554 \
//     --dart-define=API_BASE_URL=http://10.0.2.2:4000/api/v1 \
//     --dart-define=AUTH_EMULATOR_HOST=10.0.2.2:9099
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:saarthee/core/api/api_client.dart';
import 'package:saarthee/core/capture/evidence_capture.dart';
import 'package:saarthee/core/l10n/app_localizations.dart';
import 'package:saarthee/core/settings/app_settings.dart';
import 'package:saarthee/core/theme/app_theme.dart';
import 'package:saarthee/core/theme/motion.dart';
import 'package:saarthee/features/issue_actions/issue_actions_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/report/report_fakes.dart';
import 'support/lifecycle_api.dart';

/// The app's lifecycle routes, signed in as [token], with the camera/GPS faked.
Future<void> pumpAs(WidgetTester t, String token, String issueId) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final dio = userDio(token)..options.contentType = Headers.jsonContentType;
  final router = GoRouter(
    initialLocation: '/issues/$issueId',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SizedBox()),
      ...issueActionsRoutes,
    ],
  );
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        apiClientProvider.overrideWithValue(ApiClient(dio)),
        evidenceCaptureProvider.overrideWithValue(
          FakeEvidenceCapture(
            fix: const Fix(
              latitude: issueLat + 30 / 111195,
              longitude: issueLng,
              accuracy: 8,
            ),
          ),
        ),
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
        builder: (context, app) => MotionScope(child: app!),
      ),
    ),
  );
  await waitFor(t, find.byKey(const ValueKey('statusChip.markedFixed')));
}

/// Pumps frames until [finder] matches (the in-button progress never settles).
Future<void> waitFor(WidgetTester t, Finder finder, {int seconds = 20}) async {
  for (var i = 0; i < seconds * 10; i++) {
    await t.pump(SaartheeMotion.short.duration);
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for $finder');
}

Future<void> answer(WidgetTester t, {required bool fixed}) async {
  await t.tap(find.byKey(const Key('lifecycle.verify')));
  await waitFor(t, find.byKey(const Key('verify.yes')));
  await t.tap(find.byKey(Key(fixed ? 'verify.yes' : 'verify.no')));
  await waitFor(t, find.byKey(const Key('verify.take')));
  await t.tap(find.byKey(const Key('verify.take')));
  await waitFor(t, find.text("You're about 30 m from the problem."));
  await t.tap(find.byKey(const Key('issueActions.send')));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Dio moderator;
  late Dio reporterApi;
  late String reporterToken;

  setUpAll(() async {
    expect(apiBase, isNotEmpty, reason: 'pass --dart-define=API_BASE_URL');
    expect(
      emulatorHost,
      isNotEmpty,
      reason: 'pass --dart-define=AUTH_EMULATOR_HOST',
    );
    moderator = userDio(await signIn(moderatorPhone));
    reporterToken = await signIn(newTestPhone());
    reporterApi = userDio(reporterToken);
  });

  Future<String> fixedIssue() async {
    final id = await reportIssue(reporterApi);
    await setStatus(moderator, id, 'acknowledged');
    await setStatus(moderator, id, 'marked_fixed');
    expect(await lifecycleStatus(moderator, id), 'marked_fixed');
    return id;
  }

  testWidgets('a neighbour 30 m away says "Yes, it\'s fixed" → Verified', (
    t,
  ) async {
    final id = await fixedIssue();
    final neighbour = await signIn(newTestPhone());
    await pumpAs(t, neighbour, id);
    await answer(t, fixed: true);
    await waitFor(t, find.text("Thanks for checking. It's now Verified."));
    await waitFor(t, find.byKey(const ValueKey('statusChip.verified')));
    expect(await lifecycleStatus(moderator, id), 'verified');
  });

  testWidgets('the reporter says "Still not fixed" → Reopened', (t) async {
    final id = await fixedIssue();
    await pumpAs(t, reporterToken, id);
    await answer(t, fixed: false);
    await waitFor(t, find.text("Thanks for checking. It's been reopened."));
    await waitFor(t, find.byKey(const ValueKey('statusChip.reopened')));
    expect(await lifecycleStatus(moderator, id), 'reopened');
  });
}
