// Staff console Gujarati pass: localized error codes (never the server's
// English message), one language toggle in the console header, titles in the
// app language, and the organiser dropdown.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/api/app_error.dart';
import 'package:saarthee/core/api/error_messages.dart';
import 'package:saarthee/core/l10n/app_localizations.dart';
import 'package:saarthee/core/motion/haptics.dart';
import 'package:saarthee/core/settings/app_settings.dart';
import 'package:saarthee/core/theme/app_theme.dart';
import 'package:saarthee/core/theme/motion.dart';
import 'package:saarthee/core/theme/tokens.dart';
import 'package:saarthee/core/wards/wards_repository.dart';
import 'package:saarthee/features/alerts/data/alert_models.dart';
import 'package:saarthee/features/auth/application/session_controller.dart';
import 'package:saarthee/features/staff/alerts/application/staff_alerts_providers.dart';
import 'package:saarthee/features/staff/alerts/data/staff_alerts_api.dart';
import 'package:saarthee/features/staff/alerts/presentation/composer_fields.dart';
import 'package:saarthee/features/staff/alerts/presentation/staff_alerts_list_screen.dart';
import 'package:saarthee/features/staff/content/data/staff_content_api.dart';
import 'package:saarthee/features/staff/content/presentation/content_form.dart';
import 'package:saarthee/features/staff/content/presentation/staff_initiative_form_screen.dart';
import 'package:saarthee/features/staff/shared/rep_shared.dart';
import 'package:saarthee/features/staff/shared/staff_widgets.dart';
import 'package:saarthee/features/staff/shell/staff_login_screen.dart';

import '../helpers/fake_haptics.dart';
import '../helpers/fake_wards.dart';
import '../helpers/motion.dart';
import 'staff_harness.dart';

const _serverMessage = 'English server text that must never show';

/// Code → expected ARB getter.
final _codes = <String, String Function(AppLocalizations)>{
  'ALERT_STATE_INVALID': (l) => l.errorAlertStateInvalid,
  'ALERT_APPROVALS_MISSING': (l) => l.errorAlertApprovalsMissing,
  'ALERT_ALREADY_APPROVED': (l) => l.errorAlertAlreadyApproved,
  'ALERT_SECOND_APPROVER_ADMIN': (l) => l.errorAlertSecondApproverAdmin,
  'ALERT_ALREADY_SUPERSEDED': (l) => l.errorAlertSuperseded,
  'ALERT_INCOMPLETE': (l) => l.errorAlertIncomplete,
  'MERGE_INVALID': (l) => l.errorMergeInvalid,
  'SELF_SUSPEND': (l) => l.errorSelfSuspend,
  'SELF_ROLE_CHANGE': (l) => l.staffUsersSelf,
  'USER_STATE_INVALID': (l) => l.errorUserStateInvalid,
  'ROLE_CHANGE_INVALID': (l) => l.errorRoleChangeInvalid,
  'SETTING_UNKNOWN': (l) => l.errorSettingUnknown,
  'INITIATIVE_NOT_STARTED': (l) => l.errorInitiativeNotStarted,
  'NOT_VERIFIED': (l) => l.errorNotVerified,
  'ALREADY_REPLIED': (l) => l.errorAlreadyReplied,
};

final _gujarati = RegExp('[઀-૿]');

class _FakeContentApi implements StaffContentApi {
  @override
  Future<List<Map<String, dynamic>>> services({
    bool brokenOnly = false,
  }) async => [
    {
      'id': 's1',
      'slug': 'rti',
      'nameEn': 'Right to information',
      'nameGu': 'માહિતી અધિકાર',
      'category': 'information',
      'linkOk': true,
      'isActive': true,
    },
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

StaffAlert _alert() => StaffAlert(
  id: 'a1',
  type: AlertType.waterCut,
  severity: AlertSeverity.warning,
  titleEn: 'Water cut in Navrangpura',
  titleGu: 'નવરંગપુરામાં પાણી બંધ',
  bodyEn: 'Body',
  bodyGu: 'વિગત',
  sourceName: 'AMC',
  sourceUrl: 'https://ahmedabadcity.gov.in/',
  validFrom: DateTime.utc(2026, 10, 4, 4),
  validTo: DateTime.utc(2026, 10, 4, 12),
  scope: 'city',
  wardIds: const [],
  status: 'draft',
  origin: 'manual',
  approvals: const [],
  approvalsNeeded: 1,
);

/// [home] alone under a signed-in admin, in [lang].
Future<void> _pumpAlone(
  WidgetTester t,
  Widget home, {
  String lang = 'gu',
  List overrides = const [],
}) async {
  t.view.physicalSize = const Size(1000, 1600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final prefs = await testPrefs({PrefKeys.languageCode: lang});
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        saartheeHapticsProvider.overrideWithValue(FakeSaartheeHaptics()),
        sessionProvider.overrideWith(() => FakeSession('admin')),
        wardsRepositoryProvider.overrideWithValue(FakeWardsRepository()),
        ...overrides,
      ],
      child: MaterialApp(
        locale: Locale(lang),
        theme: AppTheme.light(),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MotionScope(child: child!),
        home: home,
      ),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  group('staffErrorMessage', () {
    for (final lang in ['en', 'gu']) {
      final l10n = lookupAppLocalizations(Locale(lang));
      for (final MapEntry(key: code, value: expected) in _codes.entries) {
        test('$lang: $code', () {
          final e = AppError(code: code, message: _serverMessage);
          final text = staffErrorMessage(l10n, e);
          expect(text, expected(l10n));
          expect(text, isNot(contains(_serverMessage)));
          expect(text, isNot(contains(code)));
          if (lang == 'gu') expect(text, contains(_gujarati));
          // The staff action wrapper and the rep mapper agree.
          expect(staffErrorText(l10n, e), text);
          expect(repErrorMessage(l10n, e), text);
        });
      }
      test('$lang: unknown codes and non-API errors fall back to ARB', () {
        const unknown = AppError(
          code: 'SOMETHING_NEW',
          message: _serverMessage,
        );
        expect(staffErrorMessage(l10n, unknown), l10n.errorInternal);
        expect(staffErrorMessage(l10n, StateError('boom')), l10n.errorInternal);
        const notFound = AppError(code: 'NOT_FOUND', message: _serverMessage);
        expect(staffErrorMessage(l10n, notFound), l10n.errorNotFound);
      });
      test('$lang: citizen codes IDEMPOTENCY_KEY_REUSED, CCRS_NOT_LINKED', () {
        expect(
          appErrorMessage(l10n, const AppError(code: 'IDEMPOTENCY_KEY_REUSED')),
          l10n.errorIdempotencyReused,
        );
        expect(
          appErrorMessage(l10n, const AppError(code: 'CCRS_NOT_LINKED')),
          l10n.errorCcrsNotLinked,
        );
      });
    }
  });

  test('composer maps server fields and issues without raw keys', () {
    expect(composerServerField('target.wardIds'), 'area');
    expect(composerServerField('titleGu'), 'titleGu');
    expect(composerServerProblem('Required'), 'required');
    expect(
      composerServerProblem('String must contain at most 80 character(s)'),
      'tooLong',
    );
    expect(composerServerProblem('Invalid enum value'), 'invalid');
    expect(
      composerServerProblem('Array must contain at least 1', field: 'area'),
      'required',
    );
    final gu = lookupAppLocalizations(const Locale('gu'));
    expect(composerProblemText(gu, 'invalid'), gu.staffAlertsErrInvalid);
  });

  test('content form shows ARB text for server issues', () {
    final gu = lookupAppLocalizations(const Locale('gu'));
    expect(contentServerIssue(gu, 'Required'), gu.staffContentErrorRequired);
    expect(contentServerIssue(gu, 'Invalid url'), gu.staffContentErrorHttps);
    expect(contentServerIssue(gu, 'Expected number'), gu.errorValidationFailed);
  });

  group('language toggle', () {
    testWidgets('console header shows it once (shell page)', (t) async {
      await pumpStaff(t, location: '/staff', role: 'admin');
      expect(find.byKey(const Key('languageToggle')), findsOneWidget);
    });

    testWidgets('once on a StaffPageScaffold page (alerts)', (t) async {
      await pumpStaff(
        t,
        location: '/staff/alerts',
        role: 'admin',
        overrides: [
          staffAlertsListProvider.overrideWith((ref, tab) async => [_alert()]),
        ],
      );
      expect(find.byKey(const Key('languageToggle')), findsOneWidget);
    });

    testWidgets('once on a StaffPage page (services), at 360 dp too', (
      t,
    ) async {
      await pumpStaff(
        t,
        location: '/staff/services',
        role: 'admin',
        size: const Size(360, 740),
        overrides: [
          staffContentApiProvider.overrideWithValue(_FakeContentApi()),
        ],
      );
      expect(find.byKey(const Key('languageToggle')), findsOneWidget);
      expect(find.byKey(const Key('staff.signOut')), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('sign-in page has it once, top-right', (t) async {
      await _pumpAlone(t, const StaffLoginScreen(), lang: 'en');
      final toggle = find.byKey(const Key('languageToggle'));
      expect(toggle, findsOneWidget);
      final box = t.getRect(toggle);
      expect(box.right, greaterThan(1000 - 80));
      expect(box.top, lessThan(80));
    });
  });

  testWidgets('alerts list shows the Gujarati title in Gujarati', (t) async {
    await _pumpAlone(
      t,
      const StaffAlertsListScreen(),
      overrides: [
        staffAlertsListProvider.overrideWith((ref, tab) async => [_alert()]),
      ],
    );
    expect(find.text('નવરંગપુરામાં પાણી બંધ'), findsOneWidget);
    expect(find.text('Water cut in Navrangpura'), findsNothing);
  });

  testWidgets('alerts list keeps the English title in English', (t) async {
    await _pumpAlone(
      t,
      const StaffAlertsListScreen(),
      lang: 'en',
      overrides: [
        staffAlertsListProvider.overrideWith((ref, tab) async => [_alert()]),
      ],
    );
    expect(find.text('Water cut in Navrangpura'), findsOneWidget);
  });

  testWidgets('organiser is a dropdown with Gujarati labels', (t) async {
    await _pumpAlone(t, const StaffInitiativeFormScreen());
    final field = find.byKey(const Key('form.organiser'));
    expect(field, findsOneWidget);
    expect(
      find.descendant(of: field, matching: find.byType(EditableText)),
      findsNothing,
    );
    expect(find.text('રહેવાસી મંડળ (RWA)'), findsOneWidget);
    expect(find.textContaining('AMC/RWA'), findsNothing);
    expect(find.textContaining('AMC / RWA'), findsNothing);
  });
}
