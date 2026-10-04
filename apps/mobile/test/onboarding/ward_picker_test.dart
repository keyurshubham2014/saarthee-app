// T-03-16 ward picker: zone grouping, search by name/number, no match,
// offline cache banner, error state.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:saarthee/core/settings/app_settings.dart';
import 'package:saarthee/core/wards/ward_providers.dart';
import 'package:saarthee/core/wards/wards_repository.dart';

import '../helpers/app.dart';
import '../helpers/fake_wards.dart';

Future<void> _openPicker(WidgetTester t, FakeWardsRepository repo) async {
  await pumpApp(
    t,
    prefs: {PrefKeys.languageCode: 'en'},
    overrides: [
      wardsRepositoryProvider.overrideWithValue(repo),
      deviceLocatorProvider.overrideWithValue(FakeDeviceLocator()),
    ],
  );
  GoRouter.of(t.element(find.text('Continue'))).go('/onboarding/ward');
  await t.pumpAndSettle();
  await t.tap(find.byKey(const Key('ward.choose')));
  await t.pump();
  await t.pump(const Duration(milliseconds: 500));
  await t.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('groups by zone and filters by name and number', (t) async {
    await _openPicker(t, FakeWardsRepository());
    expect(find.byKey(const ValueKey('wardPicker.zone.z-w')), findsOneWidget);
    expect(find.byKey(const ValueKey('wardPicker.zone.z-n')), findsOneWidget);
    await t.enterText(find.byKey(const Key('wardPicker.search')), 'pal');
    await t.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('wardPicker.ward.w12')), findsOneWidget);
    expect(find.byKey(const ValueKey('wardPicker.ward.w13')), findsNothing);
    await t.enterText(find.byKey(const Key('wardPicker.search')), '13');
    await t.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('wardPicker.ward.w13')), findsOneWidget);
    expect(find.byKey(const ValueKey('wardPicker.ward.w12')), findsNothing);
    await t.enterText(find.byKey(const Key('wardPicker.search')), 'zzz');
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('No ward matches “zzz”.'), findsOneWidget);
  });

  testWidgets('selecting a ward returns it to the step', (t) async {
    await _openPicker(t, FakeWardsRepository());
    await t.tap(find.byKey(const ValueKey('wardPicker.ward.w12')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('wardPicker.list')), findsNothing);
  });

  testWidgets('cached list shows the offline banner', (t) async {
    await _openPicker(
      t,
      FakeWardsRepository(list: const WardsResult(testWards, fromCache: true)),
    );
    expect(find.byKey(const ValueKey('wardPicker.ward.w12')), findsOneWidget);
    expect(find.textContaining("You're offline"), findsOneWidget);
  });

  testWidgets('no cache + API down → error state with Try again', (t) async {
    final repo = FakeWardsRepository(listError: WardFailure.unavailable);
    await _openPicker(t, repo);
    expect(find.byKey(const Key('wardPicker.error')), findsOneWidget);
    expect(find.text("We couldn't load wards right now."), findsOneWidget);
    final before = repo.listCalls;
    await t.tap(find.text('Try again'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    expect(repo.listCalls, greaterThan(before));
  });
}
