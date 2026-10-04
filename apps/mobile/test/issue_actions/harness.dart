import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:saarthee/core/capture/evidence_capture.dart';
import 'package:saarthee/core/connectivity/connectivity_provider.dart';
import 'package:saarthee/core/l10n/app_localizations.dart';
import 'package:saarthee/core/motion/haptics.dart';
import 'package:saarthee/core/settings/app_settings.dart';
import 'package:saarthee/core/settings/motion_preference.dart';
import 'package:saarthee/core/theme/app_theme.dart';
import 'package:saarthee/core/theme/motion.dart';
import 'package:saarthee/features/issue_actions/application/escalation.dart';
import 'package:saarthee/features/issue_actions/data/issue_actions_api.dart';
import 'package:saarthee/features/issue_actions/issue_actions_routes.dart';

import '../helpers/fake_haptics.dart';
import '../helpers/motion.dart';
import '../report/report_fakes.dart';
import 'fakes.dart';

/// Home placeholder so `go('/')` has somewhere to land.
const homeKey = Key('test.home');

class IssueHarness {
  IssueHarness(this.router, this.container);
  final GoRouter router;
  final ProviderContainer container;
}

/// Pumps the real TASK-06 routes in a themed, localized router app.
Future<IssueHarness> pumpIssueRoutes(
  WidgetTester t, {
  required String initial,
  FakeIssueActionsApi? api,
  EvidenceCapture? capture,
  FakeSaartheeHaptics? haptics,
  FakeLauncher? launcher,
  bool? reduced,
  bool disableAnimations = false,
  Locale locale = const Locale('en'),
  bool online = true,
}) async {
  t.view.physicalSize = const Size(400, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final prefs = await testPrefs();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      saartheeHapticsProvider.overrideWithValue(
        haptics ?? FakeSaartheeHaptics(),
      ),
      issueActionsApiProvider.overrideWithValue(api ?? FakeIssueActionsApi()),
      evidenceCaptureProvider.overrideWithValue(
        capture ?? FakeEvidenceCapture(),
      ),
      escalationLauncherProvider.overrideWithValue(launcher ?? FakeLauncher()),
      isOnlineProvider.overrideWith((ref) => Stream.value(online)),
      if (reduced != null) reducedMotionProvider.overrideWithValue(reduced),
    ],
  );
  addTearDown(container.dispose);
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: SizedBox(key: homeKey)),
      ),
      ...issueActionsRoutes,
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
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: disableAnimations),
          child: MotionScope(child: app!),
        ),
      ),
    ),
  );
  await t.pump();
  await t.pump(SaartheeMotion.medium.duration);
  return IssueHarness(router, container);
}

/// Lets futures resolve and route transitions finish without pumpAndSettle
/// (the in-button progress bar animates forever).
Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(SaartheeMotion.medium.duration);
  }
}
