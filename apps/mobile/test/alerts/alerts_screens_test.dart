// W-08-03 (AC-9): Alerts tab states + detail; W-08-04 (AC-10, AC-11): settings 6th ward, visitor prompt.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/api/app_error.dart';
import 'package:saarthee/core/settings/app_settings.dart';
import 'package:saarthee/core/wards/wards_repository.dart';
import 'package:saarthee/core/widgets/widgets.dart';
import 'package:saarthee/features/alerts/data/alerts_api.dart';
import 'package:saarthee/features/alerts/data/alert_models.dart';
import 'package:saarthee/features/auth/application/session_controller.dart';

import '../helpers/app.dart';
import '../helpers/fake_wards.dart';
import 'alert_fakes.dart';

Map<String, Object> _prefs({Map<String, Object> extra = const {}}) => {
  ...onboardedPrefs(),
  PrefKeys.homeWard: jsonEncode(paldi.toPrefsJson()),
  ...extra,
};

Future<FakeAlertsApi> _open(
  WidgetTester t, {
  FakeAlertsApi? api,
  bool signedIn = true,
  Map<String, Object> extraPrefs = const {},
  bool settle = true,
}) async {
  final fake = api ?? FakeAlertsApi();
  await pumpApp(
    t,
    prefs: _prefs(extra: extraPrefs),
    overrides: [
      alertsApiProvider.overrideWithValue(fake),
      sessionProvider.overrideWith(() => FakeSession(signedIn: signedIn)),
      wardsRepositoryProvider.overrideWithValue(FakeWardsRepository()),
    ],
  );
  await t.tap(find.byKey(const Key('nav.3')));
  if (settle) {
    await t.pumpAndSettle();
  } else {
    await t.pump();
  }
  return fake;
}

void main() {
  testWidgets(
    'Critical first as a solid card, Info tinted; Past tab; detail with source and independence line',
    (t) async {
      final api = FakeAlertsApi()
        ..active = [
          alertJson(id: 'c1', severity: 'critical', title: 'Severe heat today'),
          alertJson(id: 'i1'),
        ]
        ..past = [
          alertJson(id: 'e1', status: 'expired', title: 'Old water cut'),
        ];
      api.details['c1'] = alertJson(
        id: 'c1',
        severity: 'critical',
        title: 'Severe heat today',
      );
      await _open(t, api: api);
      final cards = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey &&
            '${(w.key! as ValueKey).value}'.startsWith('alertTile.'),
      );
      expect(cards, findsNWidgets(2));
      expect(
        t.getTopLeft(find.byKey(const ValueKey('alertTile.c1'))).dy,
        lessThan(t.getTopLeft(find.byKey(const ValueKey('alertTile.i1'))).dy),
      );
      expect(find.byKey(const ValueKey('alertCard.critical')), findsOneWidget);
      expect(find.text('Critical'), findsOneWidget);
      expect(find.text('Ward 12 Paldi'), findsNWidgets(2));
      await t.tap(find.text('Past'));
      await t.pumpAndSettle();
      expect(find.text('Old water cut'), findsOneWidget);
      await t.tap(find.text('Active'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('alertTile.c1')));
      await t.pumpAndSettle();
      expect(find.text('Where'), findsOneWidget);
      expect(
        find.text('Source: AMC Water Department · Relayed by Saarthee'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('independenceFooter')), findsOneWidget);
      expect(find.text('Turn off alerts like this'), findsOneWidget);
    },
  );

  testWidgets('loading skeleton, empty, error with retry, and offline cache', (
    t,
  ) async {
    final gate = Completer<void>();
    final api = FakeAlertsApi()..gate = gate.future;
    await _open(t, api: api, settle: false);
    await t.pump();
    expect(find.byType(SkeletonList), findsOneWidget);
    gate.complete();
    await t.pumpAndSettle();
    expect(find.text('No active alerts for your wards.'), findsOneWidget);

    api.listError = const AppError(code: 'INTERNAL_ERROR');
    await t.tap(find.text('Past'));
    await t.pumpAndSettle();
    expect(find.text("We couldn't load alerts."), findsOneWidget);
    api.listError = null;
    api.past = [alertJson(id: 'e1', status: 'expired', title: 'Old water cut')];
    await t.tap(find.text('Try again'));
    await t.pumpAndSettle();
    expect(find.text('Old water cut'), findsOneWidget);
  });

  testWidgets('offline: last loaded list with the offline banner', (t) async {
    final api = FakeAlertsApi()..listError = const AppError.offline();
    await _open(
      t,
      api: api,
      extraPrefs: {
        'saarthee.alerts.cache.active': jsonEncode([
          alertJson(id: 'x1', title: 'Cached alert'),
        ]),
      },
    );
    expect(find.text('Cached alert'), findsOneWidget);
    expect(
      find.text("You're offline. Showing the alerts loaded last time."),
      findsOneWidget,
    );
  });

  testWidgets(
    'settings: 6th extra ward refused; muting saves; visitor sees the sign-in prompt',
    (t) async {
      final api = FakeAlertsApi()
        ..subs = const AlertSubscriptions(
          extraWardIds: ['e1', 'e2', 'e3', 'e4', 'e5'],
        );
      await _open(t, api: api, signedIn: false);
      await t.tap(find.byKey(const ValueKey('alertsSettingsAction')));
      await t.pumpAndSettle();
      expect(
        find.text('Sign in to keep these settings on all your devices.'),
        findsOneWidget,
      );
      await t.scrollUntilVisible(
        find.byKey(const ValueKey('alertsAddWard')),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      await t.tap(find.byKey(const ValueKey('alertsAddWard')));
      await t.pump();
      expect(find.text('You can add up to 5 extra wards.'), findsOneWidget);
      await t.pumpAndSettle();
      final road = find.descendant(
        of: find.byKey(const ValueKey('alertType.road_closure')),
        matching: find.byType(Switch),
      );
      await t.scrollUntilVisible(
        road,
        100,
        scrollable: find.byType(Scrollable).last,
      );
      await t.tap(road);
      await t.pumpAndSettle();
      expect(api.puts.last.mutedTypes, {AlertType.roadClosure});
    },
  );
}
