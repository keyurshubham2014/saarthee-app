// T-03-13 onboarding language, T-03-14 instant language switch + sync.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/settings/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/app.dart';
import '../helpers/fake_haptics.dart';

void main() {
  group('T-03-13 language step', () {
    testWidgets('fresh install opens language with both titles', (t) async {
      await pumpApp(t);
      expect(find.text('Choose your language'), findsOneWidget);
      expect(find.text('ભાષા પસંદ કરો'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget); // device locale en
    });

    testWidgets('choosing ગુજરાતી re-renders, persists, haptic', (t) async {
      final haptics = FakeSaartheeHaptics();
      await pumpApp(t, haptics: haptics);
      await t.tap(find.byKey(const Key('onboarding.language.gu')));
      await t.pumpAndSettle();
      expect(find.text('આગળ વધો'), findsOneWidget);
      expect(haptics.calls, contains('selection'));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(PrefKeys.languageCode), 'gu');
      await t.tap(find.byKey(const Key('onboarding.language.continue')));
      await t.pumpAndSettle();
      expect(find.text('જણાવો. અનુસરો. સુધરતું જુઓ.'), findsOneWidget);
    });
  });

  group('T-03-14 instant switch', () {
    testWidgets('header toggle switches the whole tree, syncs once', (t) async {
      final sync = FakePreferenceSync();
      await pumpApp(t, prefs: onboardedPrefs(), sync: sync);
      expect(find.text('Namaste'), findsOneWidget);
      await t.tap(find.byKey(const Key('languageToggle')).first);
      await t.pumpAndSettle();
      expect(find.text('નમસ્તે'), findsOneWidget);
      expect(find.text('હોમ'), findsOneWidget); // nav label
      expect(sync.languages, ['gu']);
    });

    testWidgets('settings radio switches language in place', (t) async {
      final sync = FakePreferenceSync();
      await pumpApp(t, prefs: onboardedPrefs(), sync: sync);
      await t.tap(find.byKey(const Key('nav.4')));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.byKey(const Key('myWard.settings')),
        120,
        scrollable: find.byType(Scrollable).hitTestable().first,
      );
      await t.tap(find.byKey(const Key('myWard.settings')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('settings.lang.gu')));
      await t.pumpAndSettle();
      expect(find.text('સેટિંગ્સ'), findsWidgets); // still on settings
      expect(find.text('મારો વોર્ડ'), findsWidgets);
      expect(sync.languages, ['gu']);
    });
  });
}
