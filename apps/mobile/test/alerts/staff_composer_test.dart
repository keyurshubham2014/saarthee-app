// W-08-06 (AC-1, AC-15): staff composer error summary focus, preview in both languages, 403 for non-staff.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/wards/wards_repository.dart';
import 'package:saarthee/features/auth/application/session_controller.dart';
import 'package:saarthee/features/auth/data/account_models.dart';
import 'package:saarthee/features/staff/alerts/application/staff_alerts_providers.dart';
import 'package:saarthee/features/staff/alerts/presentation/staff_alert_composer_screen.dart';

import '../helpers/fake_wards.dart';
import '../helpers/motion.dart';

class _Staff extends SessionController {
  _Staff(this.role);

  final String role;

  @override
  SessionState build() => SessionState(
    token: 'session-jwt',
    restored: true,
    me: Me(
      id: 'u1',
      displayName: 'Esha',
      phoneMasked: null,
      language: 'en',
      role: role,
      homeWard: null,
      consents: const [],
    ),
  );
}

final _now = DateTime.utc(2030, 1, 10, 5, 30);

Future<void> _pump(WidgetTester t, String role) async {
  t.view.physicalSize = const Size(800, 2400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await pumpMotion(
    t,
    StaffAlertComposerScreen(now: _now),
    overrides: [
      sessionProvider.overrideWith(() => _Staff(role)),
      wardsRepositoryProvider.overrideWithValue(FakeWardsRepository()),
    ],
  );
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'save with problems → focused error summary with field links; nothing sent',
    (t) async {
      await _pump(t, 'moderator');
      await t.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('composer.titleEn')),
          matching: find.byType(TextFormField),
        ),
        'x' * 90,
      );
      await t.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('composer.sourceUrl')),
          matching: find.byType(TextFormField),
        ),
        'http://amc.in',
      );
      await t.ensureVisible(find.byKey(const ValueKey('composerSave')));
      await t.tap(find.byKey(const ValueKey('composerSave')));
      await t.pumpAndSettle();
      final summary = find.byKey(const ValueKey('composerErrorSummary'));
      expect(summary, findsOneWidget);
      expect(
        find.descendant(
          of: summary,
          matching: find.textContaining('Title (English): Too long.'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: summary,
          matching: find.textContaining('Source link: Use a secure link'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: summary,
          matching: find.textContaining('Area: Fill this in.'),
        ),
        findsOneWidget,
      );
      final focus = Focus.of(
        t.element(
          find.descendant(of: summary, matching: find.byType(Column)).first,
        ),
      );
      expect(focus.hasFocus, isTrue);
    },
  );

  testWidgets('live preview shows the citizen card in English and Gujarati', (
    t,
  ) async {
    await _pump(t, 'admin');
    await t.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('composer.titleEn')),
        matching: find.byType(TextFormField),
      ),
      'Water cut in Paldi',
    );
    await t.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('composer.titleGu')),
        matching: find.byType(TextFormField),
      ),
      'પાલડીમાં પાણી બંધ',
    );
    await t.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('composerPreview.en')),
        matching: find.text('Water cut in Paldi'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('composerPreview.gu')),
        matching: find.text('પાલડીમાં પાણી બંધ'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('composerPreview.gu')),
        matching: find.text('માહિતી'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a citizen session sees the no-access state', (t) async {
    await _pump(t, 'citizen');
    expect(find.text("You don't have access to this page."), findsOneWidget);
  });

  test(
    'composerProblems: Gujarati required only for submit; 14-day window',
    () {
      final d = ComposerDraft(
        titleEn: 'Water cut in Paldi',
        bodyEn: 'No water from 10 to 4.',
        sourceName: 'AMC',
        sourceUrl: 'https://ahmedabadcity.gov.in',
        validFrom: _now,
        validTo: _now.add(const Duration(hours: 6)),
        wardIds: const ['w12'],
      );
      expect(composerProblems(d, now: _now), isEmpty);
      expect(
        composerProblems(d, now: _now, forSubmit: true).keys,
        containsAll(['titleGu', 'bodyGu']),
      );
      d.validTo = _now.add(const Duration(days: 20));
      expect(composerProblems(d, now: _now)['validTo'], 'window');
    },
  );
}
