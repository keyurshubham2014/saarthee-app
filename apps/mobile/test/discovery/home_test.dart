// W-07-01 Home feed states, ward alert card, W-07-08 header band + one sunrise,
// first-load-only stagger, one-time Report-card pulse, W-07-09 Hero tags and
// branded refresh, W-07-10 reduced motion (Home).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:saarthee/core/api/app_error.dart';
import 'package:saarthee/core/settings/app_settings.dart';
import 'package:saarthee/core/theme/motion.dart';
import 'package:saarthee/core/theme/tokens.dart';
import 'package:saarthee/core/wards/wards_repository.dart';
import 'package:saarthee/features/alerts/data/alerts_api.dart';
import 'package:saarthee/features/home/presentation/home_screen.dart';
import 'package:saarthee/features/home/presentation/report_card_intro.dart';
import 'package:saarthee/features/initiatives/data/initiatives_repository.dart';
import 'package:saarthee/features/services/data/services_repository.dart';

import '../alerts/alert_fakes.dart';
import '../helpers/fake_wards.dart';
import '../services/fakes.dart';
import '../services/harness.dart' show homeWardPrefs;
import 'fakes.dart';
import 'harness.dart';

Future<DiscoveryHarness> pumpHome(
  WidgetTester t,
  FakeDiscoveryApi api, {
  FakeAlertsApi? alerts,
  Map<String, Object> prefs = const {},
  bool? reduced,
  bool disableAnimations = false,
}) => pumpDiscovery(
  t,
  home: const HomeScreen(),
  api: api,
  reduced: reduced,
  disableAnimations: disableAnimations,
  prefs: {...homeWardPrefs(paldi), reportPulseShownKey: true, ...prefs},
  extra: [
    GoRoute(path: '/elsewhere', builder: (_, _) => const SizedBox()),
    GoRoute(path: '/issues', builder: (_, _) => const SizedBox()),
  ],
  overrides: [
    alertsApiProvider.overrideWithValue(alerts ?? FakeAlertsApi()),
    servicesRepositoryProvider.overrideWithValue(FakeServicesRepository()),
    initiativesRepositoryProvider.overrideWithValue(
      FakeInitiativesRepository(const []),
    ),
    wardsRepositoryProvider.overrideWithValue(FakeWardsRepository()),
  ],
);

double opacityOf(WidgetTester t, Finder f) => t
    .widget<Opacity>(find.ancestor(of: f, matching: find.byType(Opacity)).first)
    .opacity;

FakeDiscoveryApi twoIssues() => FakeDiscoveryApi(
  feedItems: [
    cardJson('a', meToo: 5, overdue: true),
    cardJson('b', category: 'garbage', title: 'Garbage · Paldi', meToo: 2),
  ],
);

void main() {
  testWidgets('W-07-01 issues near you, stats; empty alerts strip hidden', (
    t,
  ) async {
    await pumpHome(t, twoIssues());
    await settle(t);
    expect(find.byKey(const Key('issueCard.a')), findsOneWidget);
    expect(find.byKey(const Key('issueCard.b')), findsOneWidget);
    expect(find.byKey(const Key('home.stats')), findsOneWidget);
    expect(find.byKey(const Key('home.alerts')), findsNothing);
    expect(find.byKey(const Key('home.seeAll')), findsOneWidget);
  });

  testWidgets('ward alert card from TASK-08 shows on Home', (t) async {
    final alerts = FakeAlertsApi()..active = [alertJson(id: 'a1')];
    await pumpHome(t, twoIssues(), alerts: alerts);
    await settle(t);
    expect(find.byKey(const Key('home.alerts')), findsOneWidget);
    expect(find.byKey(const ValueKey('home.alert.a1')), findsOneWidget);
  });

  testWidgets('W-07-01 empty ward → "No issues reported in Paldi yet."', (
    t,
  ) async {
    await pumpHome(t, FakeDiscoveryApi());
    await settle(t);
    expect(find.byKey(const Key('home.nearbyEmpty')), findsOneWidget);
    expect(find.textContaining('No issues reported in'), findsOneWidget);
    expect(find.byKey(const Key('home.stats')), findsNothing);
  });

  testWidgets('W-07-01 offline → last cached feed with the time note', (
    t,
  ) async {
    final cache = jsonEncode({
      'at': DateTime(2026, 10, 4, 10, 42).toIso8601String(),
      'feed': {
        'sections': {
          'nearbyIssues': {
            'items': [cardJson('a')],
          },
        },
      },
    });
    final api = FakeDiscoveryApi()..feedError = const AppError.offline();
    await pumpHome(
      t,
      api,
      prefs: {'saarthee.feed.cache.${paldi.id}.en': cache},
    );
    await settle(t);
    expect(find.byKey(const Key('home.offlineNote')), findsOneWidget);
    expect(find.textContaining('10:42'), findsOneWidget);
    expect(find.byKey(const Key('issueCard.a')), findsOneWidget);
  });

  testWidgets('W-07-01 network error → retry state', (t) async {
    final api = FakeDiscoveryApi()
      ..feedError = const AppError(code: 'INTERNAL_ERROR');
    await pumpHome(t, api);
    await settle(t);
    expect(find.byKey(const Key('home.feedError')), findsOneWidget);
  });

  testWidgets('W-07-08 green band, exactly one sunrise widget, overlap', (
    t,
  ) async {
    await pumpHome(t, twoIssues());
    await settle(t);
    final c = SaartheeColors.of(t.element(find.byType(HomeScreen)));
    expect(find.byKey(const Key('homeHeader.band')), findsOneWidget);
    final band = t.widget<ColoredBox>(find.byKey(const Key('homeHeader.band')));
    expect(band.color, c.primary);
    final sunrise = find.byWidgetPredicate(
      (w) =>
          (w is Material && w.color == c.sunrise) ||
          (w is ColoredBox && w.color == c.sunrise) ||
          (w is Container && w.color == c.sunrise),
    );
    expect(sunrise, findsOneWidget);
    final bandBottom = t.getBottomLeft(
      find.byKey(const Key('homeHeader.band')),
    );
    final cardRect = t.getRect(find.byKey(const Key('reportCard')));
    expect(cardRect.top, lessThan(bandBottom.dy));
    expect(cardRect.bottom, greaterThan(bandBottom.dy));
  });

  testWidgets('W-07-08 first load staggers; returning shows final state', (
    t,
  ) async {
    final h = await pumpHome(t, twoIssues());
    // Feed resolves; the first item starts rising, later items wait.
    await t.pump();
    await t.pump();
    final second = find.byKey(const Key('issueCard.b'));
    expect(opacityOf(t, second), lessThan(1));
    await settle(t);
    expect(opacityOf(t, second), 1);
    // Leave and come back: no replay, everything final on the first frame.
    h.router.go('/elsewhere');
    await settle(t, 2);
    h.router.go('/');
    await t.pump();
    await t.pump();
    expect(opacityOf(t, find.byKey(const Key('issueCard.b'))), 1);
    expect(opacityOf(t, find.byKey(const Key('reportCard'))), 1);
  });

  testWidgets('W-07-08 Report-card pulse runs once per install', (t) async {
    final h = await pumpHome(
      t,
      twoIssues(),
      prefs: {reportPulseShownKey: false},
    );
    await t.pump();
    expect(find.byKey(const Key('reportCard.pulse')), findsOneWidget);
    final prefs = h.container.read(sharedPreferencesProvider);
    expect(prefs.getBool(reportPulseShownKey), true);
    await t.pump(SaartheeMotion.long.duration);
    await settle(t, 2);
    expect(find.byKey(const Key('reportCard.pulse')), findsNothing);
  });

  testWidgets('W-07-08 pulse flag set → no pulse', (t) async {
    await pumpHome(t, twoIssues());
    await t.pump();
    expect(find.byKey(const Key('reportCard.pulse')), findsNothing);
  });

  testWidgets('W-07-10 reduced motion: final state at once, no pulse, '
      'flag still set', (t) async {
    final h = await pumpHome(
      t,
      twoIssues(),
      reduced: true,
      prefs: {reportPulseShownKey: false},
    );
    await t.pump();
    await t.pump();
    expect(find.byKey(const Key('reportCard.pulse')), findsNothing);
    expect(opacityOf(t, find.byKey(const Key('issueCard.b'))), 1);
    expect(
      h.container.read(sharedPreferencesProvider).getBool(reportPulseShownKey),
      true,
    );
  });

  testWidgets('W-07-09 cards carry Hero tags; tapping opens the detail', (
    t,
  ) async {
    final api = twoIssues()..details['a'] = detailJson('a');
    await pumpHome(t, api);
    await settle(t);
    expect(
      find.byWidgetPredicate((w) => w is Hero && w.tag == 'issue-title-a'),
      findsOneWidget,
    );
    await t.tap(find.byKey(const Key('issueCard.a')));
    await t.pump();
    // Mid-flight over `long`.
    await t.pump(SaartheeMotion.long.duration ~/ 2);
    await settle(t);
    expect(find.byKey(const Key('detail.title')), findsOneWidget);
  });

  testWidgets('W-07-09 pull to refresh: chevron shows, feed reloads', (
    t,
  ) async {
    final api = twoIssues();
    await pumpHome(t, api);
    await settle(t);
    final before = api.calls.where((c) => c.startsWith('feed')).length;
    final g = await t.startGesture(
      t.getCenter(find.byKey(const PageStorageKey('home.scroll'))),
    );
    for (var i = 0; i < 10; i++) {
      await g.moveBy(const Offset(0, 30));
      await t.pump();
    }
    // The route chevron is drawn while pulling.
    expect(find.byKey(const Key('chevronRefresh.painter')), findsOneWidget);
    await g.up();
    await t.pump();
    await settle(t);
    expect(
      api.calls.where((c) => c.startsWith('feed')).length,
      greaterThan(before),
    );
  });
}
