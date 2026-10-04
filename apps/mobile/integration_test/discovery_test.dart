// I-07-01 (TASK-07 AC-1, AC-5, AC-6, AC-8): a reported issue appears in the
// ward's issue list, its detail opens, "Me too" counts it, and the issue then
// shows in Following. Real API + Auth Emulator. Run by the integrator:
//   flutter test integration_test/discovery_test.dart -d emulator-5554 \
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
import 'package:saarthee/core/l10n/app_localizations.dart';
import 'package:saarthee/core/settings/app_settings.dart';
import 'package:saarthee/core/theme/app_theme.dart';
import 'package:saarthee/core/theme/motion.dart';
import 'package:saarthee/features/auth/application/session_controller.dart';
import 'package:saarthee/features/discovery/discovery_routes.dart';
import 'package:saarthee/features/issue_actions/issue_actions_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/discovery/harness.dart' show TestSession;
import 'support/lifecycle_api.dart';

Future<void> waitFor(WidgetTester t, Finder f) async {
  for (var i = 0; i < 100 && f.evaluate().isEmpty; i++) {
    await t.pump(SaartheeMotion.medium.duration);
  }
  expect(f, findsWidgets);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('list → detail → Me too → Following', (t) async {
    final reporter = userDio(await signIn(newTestPhone()))
      ..options.contentType = Headers.jsonContentType;
    final id = await reportIssue(reporter);
    final neighbour = userDio(await signIn(newTestPhone()))
      ..options.contentType = Headers.jsonContentType;
    final wardId =
        ((await neighbour.get<Map<String, dynamic>>('/issues/$id'))
                    .data!['issue']
                as Map)['ward']['id']
            as String;

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final router = GoRouter(
      initialLocation: '/issues?ward=$wardId',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const SizedBox()),
        ...discoveryRootRoutes,
        ...discoveryMeRoutes,
        ...issueActionsRoutes,
      ],
    );
    await t.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          apiClientProvider.overrideWithValue(ApiClient(neighbour)),
          sessionProvider.overrideWith(() => TestSession()),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light(),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      ),
    );
    await waitFor(t, find.byKey(Key('issueCard.$id')));
    await t.tap(find.byKey(Key('issueCard.$id')));
    await waitFor(t, find.byKey(const Key('detail.meToo')));
    expect(find.textContaining('Reported by a resident of'), findsOneWidget);
    await t.tap(find.byKey(const Key('detail.meToo')));
    await waitFor(t, find.text('Following'));
    router.go('/me/following');
    await waitFor(t, find.byKey(Key('issueCard.$id')));
  });
}
