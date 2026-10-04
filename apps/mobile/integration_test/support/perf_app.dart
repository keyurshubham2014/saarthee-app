// The full app for the motion perf harness (TASK-14 step 17): real router,
// shell and screens, every network-backed repository replaced by the
// widget-test fakes so each DS §6 moment is driven deterministically and
// without the API (fixture data, fake camera/GPS, signed-in session).
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/app.dart';
import 'package:saarthee/core/capture/evidence_capture.dart';
import 'package:saarthee/core/connectivity/connectivity_provider.dart';
import 'package:saarthee/core/map/civic_map.dart';
import 'package:saarthee/core/motion/haptics.dart';
import 'package:saarthee/core/settings/app_settings.dart';
import 'package:saarthee/core/settings/preference_sync.dart';
import 'package:saarthee/core/theme/tokens.dart';
import 'package:saarthee/core/wards/wards_repository.dart';
import 'package:saarthee/features/alerts/data/alerts_api.dart';
import 'package:saarthee/features/auth/application/session_controller.dart';
import 'package:saarthee/features/discovery/data/discovery_api.dart';
import 'package:saarthee/features/discovery/data/map_models.dart';
import 'package:saarthee/features/discovery/presentation/map/map_tab_screen.dart'
    show kDefaultMapCenter;
import 'package:saarthee/features/home/presentation/report_card_intro.dart';
import 'package:saarthee/features/initiatives/data/initiatives_repository.dart';
import 'package:saarthee/features/issue_actions/data/issue_actions_api.dart';
import 'package:saarthee/features/report/application/report_draft_controller.dart';
import 'package:saarthee/features/report/data/report_api.dart';
import 'package:saarthee/features/services/data/services_repository.dart';
import 'package:saarthee/features/ward/application/relay_consent.dart';
import 'package:saarthee/features/ward/data/ward_api.dart';
import 'package:saarthee/router/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test/alerts/alert_fakes.dart';
import '../../test/discovery/fakes.dart';
import '../../test/discovery/harness.dart' show TestSession;
import '../../test/helpers/app.dart';
import '../../test/helpers/fake_haptics.dart';
import '../../test/helpers/fake_wards.dart';
import '../../test/issue_actions/fakes.dart';
import '../../test/report/report_fakes.dart';
import '../../test/services/fakes.dart';
import '../../test/services/harness.dart' show homeWardPrefs;
import '../../test/ward/ward_fakes.dart';

/// All fakes of one perf run; moments tweak them before acting.
class PerfFakes {
  final discovery =
      FakeDiscoveryApi(
          feedItems: [
            for (var i = 0; i < 8; i++)
              cardJson('i$i', meToo: 3 + i, overdue: i.isEven),
          ],
          pages: [
            [for (var i = 0; i < 12; i++) cardJson('i$i', meToo: i)],
          ],
        )
        ..mapResult = MapResult(
          points: [
            for (var i = 0; i < 20; i++)
              MapPoint(
                id: 'p$i',
                lat: kDefaultMapCenter.latitude - 0.012 + (i ~/ 5) * 0.006,
                lng: kDefaultMapCenter.longitude - 0.012 + (i % 5) * 0.006,
                categorySlug: 'roads',
                status: IssueStatus.reported,
                isOverdue: false,
              ),
          ],
          clusters: [
            MapCluster(
              lat: kDefaultMapCenter.latitude + 0.003,
              lng: kDefaultMapCenter.longitude + 0.003,
              count: 9,
              topCategory: 'roads',
            ),
          ],
        );
  final issueActions = FakeIssueActionsApi();
  final alerts = FakeAlertsApi();
  final report = FakeReportApi();
  final capture = FakeEvidenceCapture();
  final ward = FakeWardApi();
  final initiatives = FakeInitiativesRepository([drive()]);
  final haptics = FakeSaartheeHaptics();
}

/// Pumps `SaartheeApp` with [fakes]. [onboarded] false starts at language
/// onboarding; [firstLaunch] true lets the Report-card ring run (MO-08).
Future<ProviderContainer> pumpPerfApp(
  WidgetTester t,
  PerfFakes fakes, {
  bool onboarded = true,
  bool firstLaunch = false,
  bool showLaunch = false,
}) async {
  SharedPreferences.setMockInitialValues({
    if (onboarded) ...onboardedPrefs(),
    if (onboarded) ...homeWardPrefs(paldi),
    if (!firstLaunch) reportPulseShownKey: true,
  });
  final prefs = await SharedPreferences.getInstance();
  final dir = Directory.systemTemp.createTempSync('perf-report-photos');
  await t.pumpWidget(const SizedBox.shrink());
  await t.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        saartheeHapticsProvider.overrideWithValue(fakes.haptics),
        preferenceSyncProvider.overrideWithValue(FakePreferenceSync()),
        sessionProvider.overrideWith(TestSession.new),
        isOnlineProvider.overrideWith((ref) => Stream.value(true)),
        mapTilesEnabledProvider.overrideWithValue(false),
        discoveryApiProvider.overrideWithValue(fakes.discovery),
        issueActionsApiProvider.overrideWithValue(fakes.issueActions),
        alertsApiProvider.overrideWithValue(fakes.alerts),
        reportApiProvider.overrideWithValue(fakes.report),
        evidenceCaptureProvider.overrideWithValue(fakes.capture),
        reportPhotoDirProvider.overrideWith((ref) async => dir),
        wardsRepositoryProvider.overrideWithValue(FakeWardsRepository()),
        wardApiProvider.overrideWithValue(fakes.ward),
        relayConsentProvider.overrideWithValue(FakeRelayConsent()),
        servicesRepositoryProvider.overrideWithValue(FakeServicesRepository()),
        initiativesRepositoryProvider.overrideWithValue(fakes.initiatives),
      ],
      child: SaartheeApp(showLaunch: showLaunch),
    ),
  );
  await t.pump();
  return ProviderScope.containerOf(t.element(find.byType(SaartheeApp)));
}

/// Router navigation (deep link).
void goTo(ProviderContainer c, String location) =>
    c.read(appRouterProvider).go(location);

/// Pushes [location] on top (back returns).
void pushTo(ProviderContainer c, String location) =>
    unawaited(c.read(appRouterProvider).push(location));
