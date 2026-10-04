// TASK-02 AC-10/AC-11 at widget level with the real 48-ward fixture:
// search "15" / "૧૫" / "nava" / "zzz" in en and gu, zone headers without a
// doubled "ઝોન", offline cache banner, nearest-confirm and outside-city.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:saarthee/core/settings/app_settings.dart';
import 'package:saarthee/core/wards/ward.dart';
import 'package:saarthee/core/wards/ward_providers.dart';
import 'package:saarthee/core/wards/wards_repository.dart';

import '../helpers/app.dart';
import '../helpers/fake_wards.dart';

final _wards = ApiWardsRepository.parseWards(
  jsonDecode(File('test/fixtures/wards.json').readAsStringSync()),
);
Ward _n(int number) => _wards.firstWhere((w) => w.number == number);

class _OutsideRepo extends FakeWardsRepository {
  @override
  Future<WardLocateResult> locate(double lat, double lng) async =>
      throw const OutsideServiceArea();
}

Future<void> _pumpWardStep(
  WidgetTester t,
  FakeWardsRepository repo, {
  String lang = 'en',
}) async {
  await pumpApp(
    t,
    prefs: {PrefKeys.languageCode: lang},
    overrides: [
      wardsRepositoryProvider.overrideWithValue(repo),
      deviceLocatorProvider.overrideWithValue(FakeDeviceLocator()),
    ],
  );
  GoRouter.of(t.element(find.byType(Scaffold).first)).go('/onboarding/ward');
  await t.pumpAndSettle();
}

Future<void> _openPicker(WidgetTester t) async {
  await t.tap(find.byKey(const Key('ward.choose')));
  await t.pump();
  await t.pump(const Duration(milliseconds: 500));
  await t.pump(const Duration(milliseconds: 500));
}

Future<void> _search(WidgetTester t, String q) async {
  await t.enterText(find.byKey(const Key('wardPicker.search')), q);
  await t.pump(const Duration(milliseconds: 500));
}

Finder _ward(int n) => find.byKey(ValueKey('wardPicker.ward.${_n(n).id}'));
Finder _zone(Ward w) => find.byKey(ValueKey('wardPicker.zone.${w.zone.id}'));

void main() {
  FakeWardsRepository repo({bool fromCache = false}) =>
      FakeWardsRepository(list: WardsResult(_wards, fromCache: fromCache));

  for (final lang in ['en', 'gu']) {
    testWidgets('AC-10 [$lang] search 15 / ૧૫ / nava / zzz', (t) async {
      await _pumpWardStep(t, repo(), lang: lang);
      await _openPicker(t);
      // Central is the first group.
      expect(_zone(_n(15)), findsOneWidget);
      for (final q in ['15', '૧૫']) {
        await _search(t, q);
        expect(_ward(15), findsOneWidget, reason: q);
        expect(_zone(_n(15)), findsOneWidget, reason: q);
        expect(_ward(5), findsNothing, reason: q);
      }
      await _search(t, 'nava');
      expect(_ward(6), findsOneWidget);
      expect(_zone(_n(6)), findsOneWidget);
      await _search(t, 'zzz');
      expect(_ward(6), findsNothing);
      expect(find.textContaining('zzz'), findsWidgets);
    });
  }

  testWidgets('AC-10 [gu] zone header shows the API name once', (t) async {
    await _pumpWardStep(t, repo(), lang: 'gu');
    await _openPicker(t);
    await _search(t, 'પાલડી');
    expect(_ward(30), findsOneWidget);
    expect(find.text('પશ્ચિમ ઝોન'), findsWidgets);
    expect(find.textContaining('ઝોન ઝોન'), findsNothing);
  });

  testWidgets('AC-10 offline after one load → cached list + banner', (t) async {
    await _pumpWardStep(t, repo(fromCache: true));
    await _openPicker(t);
    expect(find.textContaining("You're offline"), findsOneWidget);
    await _search(t, '30');
    expect(_ward(30), findsOneWidget);
  });

  testWidgets('AC-11 inside → "You\'re in Ward 30 · Paldi"', (t) async {
    final r = repo()
      ..locateResult = WardLocateResult(ward: _n(30), confirm: false);
    await _pumpWardStep(t, r);
    await t.tap(find.byKey(const Key('ward.useLocation')));
    await t.pumpAndSettle();
    expect(find.textContaining("You're in Ward 30 · Paldi"), findsOneWidget);
  });

  testWidgets('AC-11 nearest → "just outside" confirmation', (t) async {
    final r = repo()
      ..locateResult = WardLocateResult(
        ward: _n(30),
        confirm: true,
        match: WardMatch.nearest,
        distanceM: 412,
      );
    await _pumpWardStep(t, r);
    await t.tap(find.byKey(const Key('ward.useLocation')));
    await t.pumpAndSettle();
    expect(find.textContaining('just outside Ward 30 · Paldi'), findsOneWidget);
    expect(find.byKey(const Key('ward.yes')), findsOneWidget);
  });

  testWidgets('AC-11 OutsideServiceArea → outside message + list', (t) async {
    await _pumpWardStep(
      t,
      _OutsideRepo()..list = WardsResult(_wards, fromCache: false),
    );
    await t.tap(find.byKey(const Key('ward.useLocation')));
    await t.pumpAndSettle();
    expect(find.textContaining('outside Ahmedabad'), findsOneWidget);
    await _openPicker(t);
    expect(_ward(15), findsOneWidget);
  });
}
