import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:saarthee/core/api/app_error.dart';
import 'package:saarthee/core/l10n/app_localizations.dart';
import 'package:saarthee/core/motion/haptics.dart';
import 'package:saarthee/core/settings/app_settings.dart';
import 'package:saarthee/core/settings/motion_preference.dart';
import 'package:saarthee/core/theme/app_theme.dart';
import 'package:saarthee/core/theme/motion.dart';
import 'package:saarthee/features/ward/application/relay_consent.dart';
import 'package:saarthee/features/ward/data/ward_api.dart';
import 'package:saarthee/features/ward/data/ward_models.dart';
import 'package:saarthee/features/ward/presentation/election_banner.dart';
import 'package:saarthee/features/ward/presentation/message_screen.dart';
import 'package:saarthee/features/ward/presentation/representative_screen.dart';
import 'package:saarthee/features/ward/presentation/scorecard_screen.dart';
import 'package:saarthee/features/ward/presentation/ward_screen.dart';

import '../helpers/fake_haptics.dart';
import '../helpers/motion.dart';

const wardId = '00000009-0030-4000-8000-000000000000';

/// Fictional "Sample" data only (never real people or numbers).
Map<String, dynamic> repJson(
  String id,
  String name, {
  String role = 'corporator',
  bool canMessage = true,
  int? ward = 30,
  String? area,
}) => {
  'id': id,
  'nameEn': name,
  'nameGu': 'નમૂના $name',
  'role': role,
  'partyText': 'Sample Party',
  'wardNumber': role == 'corporator' ? ward : null,
  'acNameEn': area,
  'acNameGu': area,
  'initials': name.split(' ').map((w) => w[0]).take(2).join(),
  'canMessage': canMessage,
  'verified': false,
};

WardRepresentatives wardReps({
  int corporators = 4,
  int mlas = 2,
  int mps = 1,
  int acCount = 2,
  bool election = false,
  String? officePhone = '+917900003001',
}) => WardRepresentatives.fromJson({
  'ward': {
    'id': wardId,
    'number': 30,
    'nameEn': 'Paldi',
    'nameGu': 'પાલડી',
    'zone': {'nameEn': 'West', 'nameGu': 'પશ્ચિમ'},
    'officeAddressEn': 'Sample ward office address',
    'officePhone': officePhone,
    'assemblyConstituencyCount': acCount,
  },
  'corporators': [
    for (var i = 0; i < corporators; i++)
      repJson('c$i', 'Sample Corporator ${String.fromCharCode(65 + i)}'),
  ],
  'mlas': [
    for (var i = 0; i < mlas; i++)
      repJson('m$i', 'Sample Mla $i', role: 'mla', area: 'Sample AC $i'),
  ],
  'mps': [
    for (var i = 0; i < mps; i++)
      repJson('p$i', 'Sample Mp $i', role: 'mp', area: 'Sample Seat'),
  ],
  'electionMode': {
    'active': election,
    'until': election ? '2026-11-01T00:00:00.000Z' : null,
  },
});

RepDetail repDetail({
  bool canMessage = true,
  String? phone = '+917900003001',
}) => RepDetail.fromJson({
  ...repJson('c0', 'Sample Corporator A', canMessage: canMessage),
  'termStart': '2026-03-01',
  'termEnd': '2031-02-28',
  'officePhone': ?phone,
  'sourceUrl': 'https://example.org/sample-roster',
  'lastVerifiedAt': '2026-09-12',
  'areas': [
    {'kind': 'ward', 'wardNumber': 30, 'nameEn': 'Paldi', 'nameGu': 'પાલડી'},
  ],
  'electionMode': {'active': false},
});

class FakeWardApi implements WardApi {
  FakeWardApi({WardRepresentatives? reps, RepDetail? rep, this.card})
    : reps = reps ?? wardReps(),
      rep = rep ?? repDetail();

  WardRepresentatives reps;
  RepDetail rep;
  WardScorecard? card;
  Object? repsError;

  /// Errors thrown by the next sends, in order.
  final List<AppError> sendErrors = [];
  final List<RelayDraft> sent = [];
  int scorecardCalls = 0;

  @override
  Future<WardRepresentatives> wardRepresentatives(String id) async {
    if (repsError != null) throw repsError!;
    return reps;
  }

  @override
  Future<RepDetail> representative(String id) async => rep;

  @override
  Future<WardScorecard> scorecard(String id) async {
    scorecardCalls++;
    return card!;
  }

  @override
  Future<String> sendMessage(String repId, RelayDraft draft) async {
    sent.add(draft);
    if (sendErrors.isNotEmpty) throw sendErrors.removeAt(0);
    return 'msg-${sent.length}';
  }
}

class FakeRelayConsent implements RelayConsent {
  FakeRelayConsent({this.granted = true});

  @override
  bool granted;
  int grants = 0;

  @override
  Future<void> grant() async {
    grants++;
    granted = true;
  }
}

/// Pumps the TASK-09 screens under a small router (no shell, no sign-in).
Future<({ProviderContainer container, GoRouter router})> pumpWardRoutes(
  WidgetTester tester, {
  required FakeWardApi api,
  String initial = '/ward/$wardId',
  FakeRelayConsent? consent,
  FakeSaartheeHaptics? haptics,
  bool? reduced,
  bool disableAnimations = false,
  List<Uri>? launched,
}) async {
  final prefs = await testPrefs();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      saartheeHapticsProvider.overrideWithValue(
        haptics ?? FakeSaartheeHaptics(),
      ),
      if (reduced != null) reducedMotionProvider.overrideWithValue(reduced),
      wardApiProvider.overrideWithValue(api),
      relayConsentProvider.overrideWithValue(consent ?? FakeRelayConsent()),
      wardLauncherProvider.overrideWithValue((uri) async {
        launched?.add(uri);
        return true;
      }),
    ],
  );
  addTearDown(container.dispose);
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SizedBox()),
      GoRoute(
        path: '/ward/:id',
        builder: (_, s) => WardScreen(wardId: s.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'scorecard',
            builder: (_, s) => ScorecardScreen(wardId: s.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: '/representatives/:id',
        builder: (_, s) => RepresentativeScreen(repId: s.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'message',
            builder: (_, s) => MessageScreen(
              repId: s.pathParameters['id']!,
              issueId: s.uri.queryParameters['issueId'],
            ),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('en'),
        theme: AppTheme.light(),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: disableAnimations),
          child: MotionScope(child: app!),
        ),
      ),
    ),
  );
  return (container: container, router: router);
}
