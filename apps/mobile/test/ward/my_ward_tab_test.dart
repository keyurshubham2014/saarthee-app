// My Ward tab (full app shell): home ward → representatives section, the
// TASK-04 account row kept, tab return does not replay the stagger (AC-1, AC-13).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/settings/app_settings.dart';
import 'package:saarthee/core/wards/ward.dart';
import 'package:saarthee/features/ward/data/ward_api.dart';

import '../helpers/app.dart';
import 'ward_fakes.dart';

const _home = Ward(
  id: wardId,
  number: 30,
  nameEn: 'Paldi',
  nameGu: 'પાલડી',
  zone: Zone(id: 'z-w', code: 'W', nameEn: 'West', nameGu: 'પશ્ચિમ'),
);

Future<void> _tab(WidgetTester t, int i) async {
  await t.tap(find.byType(NavigationDestination).at(i));
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'home ward shows corporators with Message, account row kept, no replay on return',
    (t) async {
      await pumpApp(
        t,
        prefs: {
          ...onboardedPrefs(),
          PrefKeys.homeWard: jsonEncode(_home.toPrefsJson()),
        },
        overrides: [wardApiProvider.overrideWithValue(FakeWardApi())],
      );
      await _tab(t, 4);
      for (final id in ['c0', 'c1', 'c2', 'c3']) {
        expect(find.byKey(Key('rep.message.$id')), findsOneWidget, reason: id);
      }
      // No personal numbers: only the fictional office landline is shown.
      expect(find.textContaining('+9190'), findsNothing);
      final me = find.byKey(const Key('myWard.me'));
      await t.scrollUntilVisible(
        me,
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(me, findsOneWidget);

      await _tab(t, 0);
      await _tab(t, 4);
      final op = t.widget<Opacity>(
        find
            .ancestor(
              of: find.byKey(const Key('ward.rep.c0')),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(op.opacity, 1);
    },
  );
}
