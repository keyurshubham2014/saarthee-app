// TASK-10 widget-test harness: the staff routes in a MaterialApp.router with
// a fake staff API, a fixed `/staff/me` identity and a signed-in session.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:saarthee/core/l10n/app_localizations.dart';
import 'package:saarthee/core/motion/haptics.dart';
import 'package:saarthee/core/settings/app_settings.dart';
import 'package:saarthee/core/theme/app_theme.dart';
import 'package:saarthee/core/theme/motion.dart';
import 'package:saarthee/core/wards/wards_repository.dart';
import 'package:saarthee/features/auth/application/session_controller.dart';
import 'package:saarthee/features/auth/data/account_models.dart';
import 'package:saarthee/features/auth/data/secure_store.dart';
import 'package:saarthee/features/staff/shared/staff_api.dart';
import 'package:saarthee/features/staff/shell/staff_session.dart';
import 'package:saarthee/router/staff_routes.dart';

import '../helpers/fake_haptics.dart';
import '../helpers/fake_wards.dart';
import '../helpers/motion.dart';

class FakeSession extends SessionController {
  FakeSession(this.role);
  final String role;

  @override
  SessionState build() => SessionState(
    token: 'session-jwt',
    restored: true,
    me: Me(
      id: 'me-1',
      displayName: 'Esha',
      phoneMasked: null,
      language: 'en',
      role: role,
      homeWard: null,
      consents: const [],
    ),
  );

  @override
  Future<void> get ready async {}
}

/// Records calls; answers with canned JSON. Unlisted calls throw.
class FakeStaffApi implements StaffApi {
  final calls = <String>[];
  Json summaryJson = {
    'queues': {'sensitive': 1, 'flagged': 2, 'outOfArea': 0},
    'alertsAwaitingApproval': 3,
    'openFlags': 2,
  };
  Map<String, List<Json>> queues = {};
  Map<String, Json> issues = {};
  List<Json> candidates = [];
  Object? failNext;
  List<int> csv = '"id"\r\n"a"\r\n'.codeUnits;
  Map<String, String>? lastExport;

  Future<Json> _maybeFail(String call, Json Function() ok) async {
    calls.add(call);
    final f = failNext;
    if (f != null) {
      failNext = null;
      throw f;
    }
    return ok();
  }

  @override
  Future<Json> summary() async => summaryJson;
  @override
  Future<Json> queue(String queue, {String? cursor}) async => {
    'items': queues[queue] ?? const <Json>[],
    'nextCursor': null,
  };
  @override
  Future<Json> issue(String id) async => issues[id]!;
  @override
  Future<Json> mergeCandidates(String id) async => {'items': candidates};
  @override
  Future<Json> reviewed(String id) =>
      _maybeFail('reviewed:$id', () => issues[id]!);
  @override
  Future<Json> reject(String id, String reason, String? note) =>
      _maybeFail('reject:$id:$reason', () => issues[id]!);
  @override
  Future<Json> merge(String id, String targetId) =>
      _maybeFail('merge:$id:$targetId', () => issues[id]!);
  @override
  Future<Json> hide(String id, String reason, {bool hidden = true}) =>
      _maybeFail('hide:$id:$hidden', () => issues[id]!);
  @override
  Future<Json> status(
    String id,
    String to, {
    String? note,
    List<String> photoIds = const [],
    String? expectedStatus,
  }) => _maybeFail('status:$id:$to:${photoIds.join(',')}', () => issues[id]!);
  @override
  Future<String> uploadPhoto(String issueId, List<int> bytes) async {
    calls.add('upload:$issueId:${bytes.length}');
    return 'photo-1';
  }

  @override
  Future<List<int>> export(Map<String, String> query) async {
    lastExport = query;
    return csv;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

StaffMe staffMe(String role, {String kind = 'user'}) => StaffMe(
  actorId: 'me-1',
  actorKind: kind,
  role: role,
  displayName: 'Esha',
  wardIds: const [],
  nav: const [],
);

/// Pumps the staff console at [location] as [role] on a [size] window.
Future<({FakeStaffApi api, GoRouter router})> pumpStaff(
  WidgetTester t, {
  required String location,
  String role = 'admin',
  Size size = const Size(1280, 800),
  FakeStaffApi? api,
  bool disableAnimations = false,
  List overrides = const [],
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final fake = api ?? FakeStaffApi();
  final router = GoRouter(initialLocation: location, routes: staffRoutes);
  addTearDown(router.dispose);
  final prefs = await testPrefs();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      saartheeHapticsProvider.overrideWithValue(FakeSaartheeHaptics()),
      sessionProvider.overrideWith(() => FakeSession(role)),
      secureStoreProvider.overrideWithValue(MemorySecureStore()),
      staffMeProvider.overrideWith((ref) async => staffMe(role)),
      staffApiProvider.overrideWithValue(fake),
      wardsRepositoryProvider.overrideWithValue(FakeWardsRepository()),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  await t.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MediaQuery(
        data: MediaQueryData(size: size, disableAnimations: disableAnimations),
        child: MaterialApp.router(
          locale: const Locale('en'),
          theme: AppTheme.light(),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: router,
          builder: (context, child) => MotionScope(child: child!),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  return (api: fake, router: router);
}
