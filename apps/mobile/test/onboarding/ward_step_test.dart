// T-03-15 ward step: GPS, confirm, denied, outside city, API down, skip.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:saarthee/core/settings/app_settings.dart';
import 'package:saarthee/core/wards/ward.dart';
import 'package:saarthee/core/wards/ward_providers.dart';
import 'package:saarthee/core/wards/wards_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/app.dart';
import '../helpers/fake_wards.dart';

Future<void> _toWardStep(
  WidgetTester t, {
  FakeWardsRepository? repo,
  FakeDeviceLocator? locator,
}) async {
  await pumpApp(
    t,
    prefs: {PrefKeys.languageCode: 'en'},
    overrides: [
      wardsRepositoryProvider.overrideWithValue(repo ?? FakeWardsRepository()),
      deviceLocatorProvider.overrideWithValue(locator ?? FakeDeviceLocator()),
    ],
  );
  GoRouter.of(t.element(find.text('Continue'))).go('/onboarding/ward');
  await t.pumpAndSettle();
  expect(find.text('Set your home ward'), findsOneWidget);
}

void main() {
  testWidgets('GPS → Yes stores Ward 12 and opens Home', (t) async {
    await _toWardStep(t);
    await t.tap(find.byKey(const Key('ward.useLocation')));
    await t.pumpAndSettle();
    expect(
      find.text(
        "You're in Ward 12 · Paldi (West zone). Is this your home ward?",
      ),
      findsOneWidget,
    );
    await t.tap(find.byKey(const Key('ward.yes')));
    await t.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(PrefKeys.onboardingDone), isTrue);
    expect(prefs.getString(PrefKeys.homeWard), contains('w12'));
    expect(find.text('Ward 12 · Paldi'), findsOneWidget); // header ward line
  });

  testWidgets('confirm:true uses the just-outside wording', (t) async {
    await _toWardStep(
      t,
      repo: FakeWardsRepository(
        locateResult: const WardLocateResult(ward: paldi, confirm: true),
      ),
    );
    await t.tap(find.byKey(const Key('ward.useLocation')));
    await t.pumpAndSettle();
    expect(
      find.text('You seem to be just outside Ward 12 · Paldi. Is this right?'),
      findsOneWidget,
    );
  });

  testWidgets('permission denied → message + Open settings', (t) async {
    final locator = FakeDeviceLocator(failure: LocatorFailure.deniedForever);
    await _toWardStep(t, locator: locator);
    await t.tap(find.byKey(const Key('ward.useLocation')));
    await t.pumpAndSettle();
    expect(
      find.text(
        'Location is off. You can choose your ward from the list instead.',
      ),
      findsOneWidget,
    );
    await t.tap(find.byKey(const Key('ward.openSettings')));
    expect(locator.settingsOpened, 1);
    expect(find.byKey(const Key('ward.choose')), findsOneWidget);
  });

  testWidgets('outside city (422) → message + list', (t) async {
    await _toWardStep(
      t,
      repo: FakeWardsRepository(locateError: WardFailure.outsideCity),
    );
    await t.tap(find.byKey(const Key('ward.useLocation')));
    await t.pumpAndSettle();
    expect(
      find.text(
        'You seem to be outside Ahmedabad. Choose your ward from the list.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('API down → Try again + Skip; skip finishes onboarding', (
    t,
  ) async {
    await _toWardStep(
      t,
      repo: FakeWardsRepository(locateError: WardFailure.unavailable),
    );
    await t.tap(find.byKey(const Key('ward.useLocation')));
    await t.pumpAndSettle();
    expect(
      find.text(
        "We couldn't load wards right now. Try again, or skip and set it later.",
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('ward.retry')), findsOneWidget);
    await t.tap(find.byKey(const Key('ward.skip')));
    await t.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(PrefKeys.onboardingDone), isTrue);
    expect(prefs.getString(PrefKeys.homeWard), isNull);
    expect(find.text('Set your ward'), findsOneWidget);
  });
}
