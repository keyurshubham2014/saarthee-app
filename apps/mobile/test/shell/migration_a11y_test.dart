// T-03-20 v1 prefs migration + admin route; T-03-19 accessibility guidelines.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:saarthee/core/settings/app_settings.dart';
import 'package:saarthee/core/widgets/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/app.dart';
import '../helpers/motion.dart';

void main() {
  group('T-03-20 v1 upgrade', () {
    testWidgets('v1 keys and draft removed, onboarding shown', (t) async {
      await pumpApp(
        t,
        prefs: {
          'inviteCode': 'RWA-PALDI',
          'groupLabel': 'Paldi RWA',
          'onboardingDone': true,
          'reportDraft': '{"step":3}',
          PrefKeys.installId: 'keep-me',
        },
      );
      final prefs = await SharedPreferences.getInstance();
      for (final k in PrefKeys.retiredV1) {
        expect(prefs.containsKey(k), isFalse, reason: k);
      }
      expect(prefs.getString(PrefKeys.installId), 'keep-me');
      expect(find.text('Choose your language'), findsOneWidget);
    });

    // TASK-10 (D11): v1 admin screens are retired; old links open the staff
    // console, which asks a signed-out operator to sign in.
    testWidgets('/admin/login redirects to the staff console sign-in', (t) async {
      FlutterSecureStorage.setMockInitialValues({});
      await pumpApp(t, prefs: onboardedPrefs());
      GoRouter.of(t.element(find.byType(NavigationBar))).go('/admin/login');
      await t.pumpAndSettle();
      expect(find.text('Sign in to Saarthee staff'), findsWidgets);
    });
  });

  group('T-03-19 accessibility guidelines', () {
    Future<void> guidelines(WidgetTester t) async {
      final handle = t.ensureSemantics();
      await expectLater(t, meetsGuideline(androidTapTargetGuideline));
      await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(t, meetsGuideline(textContrastGuideline));
      handle.dispose();
    }

    testWidgets('Home (shell + header)', (t) async {
      await pumpApp(t, prefs: onboardedPrefs());
      await guidelines(t);
    });

    testWidgets('onboarding language', (t) async {
      await pumpApp(t);
      await guidelines(t);
    });

    testWidgets('onboarding intro', (t) async {
      await pumpApp(t, prefs: {PrefKeys.languageCode: 'gu'});
      await t.tap(find.byKey(const Key('onboarding.language.continue')));
      await t.pumpAndSettle();
      await guidelines(t);
    });

    testWidgets('StepHeader announces "Step 2 of 3"', (t) async {
      final handle = t.ensureSemantics();
      await pumpMotion(
        t,
        const StepHeader(step: 2, total: 3, nextHint: 'Location'),
      );
      expect(find.bySemanticsLabel(RegExp('Step 2 of 3')), findsWidgets);
      handle.dispose();
    });
  });
}
