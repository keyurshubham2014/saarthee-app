import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:saarthee/core/connectivity/connectivity_provider.dart';
import 'package:saarthee/core/l10n/app_localizations.dart';
import 'package:saarthee/core/map/civic_map.dart';
import 'package:saarthee/core/motion/haptics.dart';
import 'package:saarthee/core/settings/app_settings.dart';
import 'package:saarthee/core/settings/motion_preference.dart';
import 'package:saarthee/core/theme/app_theme.dart';
import 'package:saarthee/core/theme/motion.dart';
import 'package:saarthee/features/auth/application/session_controller.dart';
import 'package:saarthee/features/discovery/data/discovery_api.dart';
import 'package:saarthee/features/discovery/presentation/issue_detail_screen.dart';
import 'package:saarthee/features/issue_actions/data/issue_actions_api.dart';

import '../helpers/fake_haptics.dart';
import '../helpers/motion.dart';
import '../issue_actions/fakes.dart';
import 'fakes.dart';

/// Signed in / out without Firebase; `ready` resolves at once.
class TestSession extends SessionController {
  TestSession({this.signedIn = true});

  final bool signedIn;

  @override
  SessionState build() =>
      SessionState(token: signedIn ? 'session-jwt' : null, restored: true);

  @override
  Future<void> get ready async {}
}

class DiscoveryHarness {
  DiscoveryHarness(this.router, this.container);
  final GoRouter router;
  final ProviderContainer container;
}

/// Pumps [home] at `/` with `/issues/:id` → IssueDetailScreen and [extra]
/// routes, in a themed, localized router app with fakes.
Future<DiscoveryHarness> pumpDiscovery(
  WidgetTester t, {
  required Widget home,
  required FakeDiscoveryApi api,
  List<RouteBase> extra = const [],
  FakeSaartheeHaptics? haptics,
  bool signedIn = true,
  bool? reduced,
  bool disableAnimations = false,
  Map<String, Object> prefs = const {},
  List overrides = const [],
  Locale locale = const Locale('en'),
  bool online = true,
}) async {
  t.view.physicalSize = const Size(400, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final p = await testPrefs(prefs);
  final container = ProviderContainer(
    // As in main.dart: no automatic retries (screens offer Try again).
    retry: (_, _) => null,
    overrides: [
      sharedPreferencesProvider.overrideWithValue(p),
      saartheeHapticsProvider.overrideWithValue(
        haptics ?? FakeSaartheeHaptics(),
      ),
      discoveryApiProvider.overrideWithValue(api),
      issueActionsApiProvider.overrideWithValue(FakeIssueActionsApi()),
      sessionProvider.overrideWith(() => TestSession(signedIn: signedIn)),
      mapTilesEnabledProvider.overrideWithValue(false),
      isOnlineProvider.overrideWith((ref) => Stream.value(online)),
      if (reduced != null) reducedMotionProvider.overrideWithValue(reduced),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => home),
      GoRoute(
        path: '/issues/:id',
        builder: (_, s) => IssueDetailScreen(issueId: s.pathParameters['id']!),
      ),
      ...extra,
    ],
  );
  addTearDown(router.dispose);
  await t.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        locale: locale,
        theme: AppTheme.light(),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: disableAnimations),
          child: MotionScope(child: app!),
        ),
      ),
    ),
  );
  await t.pump();
  return DiscoveryHarness(router, container);
}

/// Pumps a few `medium` frames (no pumpAndSettle: skeletons shimmer).
Future<void> settle(WidgetTester t, [int n = 6]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(SaartheeMotion.medium.duration);
  }
}
