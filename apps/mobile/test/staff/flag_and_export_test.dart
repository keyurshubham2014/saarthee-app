// W-10-05 FlagContentSheet (reasons, note counter, already reported, signed
// out) and W-10-06 export screen (phone opt-in requires a reason).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:saarthee/core/api/api_client.dart';
import 'package:saarthee/core/l10n/app_localizations.dart';
import 'package:saarthee/core/settings/app_settings.dart';
import 'package:saarthee/core/theme/motion.dart';
import 'package:saarthee/features/auth/application/session_controller.dart';
import 'package:saarthee/features/staff/exports/staff_exports_screen.dart';
import 'package:saarthee/features/staff/flags/flag_content_sheet.dart';

import '../helpers/motion.dart';
import 'staff_harness.dart';

class _FakeClient implements ApiClient {
  _FakeClient(this.reply);
  final Map<String, dynamic> reply;
  final posts = <String, Object?>{};

  @override
  Future<Map<String, dynamic>> postJson(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) async {
    posts[path] = body;
    return reply;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SignedOut extends SessionController {
  @override
  SessionState build() => const SessionState(restored: true);
  @override
  Future<void> get ready async {}
}

Future<_FakeClient> _pumpSheet(
  WidgetTester t, {
  Map<String, dynamic> reply = const {'flagId': 'f1', 'alreadyReported': false},
}) async {
  final client = _FakeClient(reply);
  await pumpMotion(
    t,
    const Scaffold(
      body: FlagContentSheet(issueId: 'i1', eventId: 'e1'),
    ),
    overrides: [apiClientProvider.overrideWithValue(client)],
  );
  return client;
}

void main() {
  testWidgets(
    'W-10-05 reasons, note counter, send disabled until a reason is chosen',
    (t) async {
      final client = await _pumpSheet(t);
      expect(find.text('Report a problem with this post'), findsOneWidget);
      for (final r in [
        'Spam or advertising',
        'Abusive or hateful',
        'Shows private information',
        'Not a civic issue',
        'Wrong location',
        'Duplicate',
        'Something else',
      ]) {
        expect(find.text(r), findsOneWidget);
      }
      await t.enterText(find.byKey(const Key('flag.note')), 'Shows a face');
      await t.pump();
      expect(find.text('12/200'), findsOneWidget);
      await t.tap(find.byKey(const Key('flag.send')));
      await t.pump();
      expect(client.posts, isEmpty);
      await t.tap(find.byKey(const Key('flag.reason.private_info')));
      await t.pump();
      await t.tap(find.byKey(const Key('flag.send')));
      await t.pumpAndSettle();
      expect(client.posts['/issues/i1/flags'], {
        'reason': 'private_info',
        'note': 'Shows a face',
        'eventId': 'e1',
      });
    },
  );

  testWidgets(
    'W-10-05 sendFlag reports "already reported" from the 200 reply',
    (t) async {
      final client = _FakeClient({'flagId': 'f1', 'alreadyReported': true});
      late WidgetRef captured;
      await pumpMotion(
        t,
        Consumer(
          builder: (context, ref, _) {
            captured = ref;
            return const SizedBox();
          },
        ),
        overrides: [apiClientProvider.overrideWithValue(client)],
      );
      expect(
        await sendFlag(captured, 'i1', reason: 'spam'),
        FlagOutcome.already,
      );
    },
  );

  testWidgets('W-10-05 signed out: sent to sign-in and back', (t) async {
    final prefs = await testPrefs();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () =>
                  showFlagContentSheet(context, ref, issueId: 'i1'),
              child: const Text('flag'),
            ),
          ),
        ),
        GoRoute(
          path: '/sign-in',
          builder: (_, s) => Text('sign-in ${s.uri.queryParameters['from']}'),
        ),
      ],
    );
    addTearDown(router.dispose);
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        sessionProvider.overrideWith(_SignedOut.new),
      ],
    );
    addTearDown(container.dispose);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
        ),
      ),
    );
    await t.tap(find.text('flag'));
    await t.pumpAndSettle();
    expect(find.text('sign-in /'), findsOneWidget);
  });

  testWidgets('W-10-06 phone numbers need a 10–200 character reason', (
    t,
  ) async {
    final r = await pumpStaff(
      t,
      location: '/staff/exports',
      overrides: [
        staffCsvSaverProvider.overrideWithValue((name, bytes) async {}),
      ],
    );
    await t.tap(find.byKey(const Key('staff.export.phone')));
    await t.pumpAndSettle();
    expect(
      find.text(
        'Phone numbers are personal data. Only include them if you must.',
      ),
      findsOneWidget,
    );
    await t.tap(find.byKey(const Key('staff.export.download')));
    await t.pumpAndSettle();
    expect(find.text('Give a reason of 10 to 200 characters.'), findsOneWidget);
    expect(r.api.lastExport, isNull);
    await t.enterText(
      find.byKey(const Key('staff.export.reason')),
      'Ward survey follow-up',
    );
    await t.tap(find.byKey(const Key('staff.export.download')));
    await t.pumpAndSettle();
    expect(r.api.lastExport, containsPair('includePhone', 'true'));
    expect(r.api.lastExport, containsPair('reason', 'Ward survey follow-up'));
    await t.pump(SaartheeMotion.toastHold);
    await t.pumpAndSettle();
  });

  testWidgets('W-10-06 default export has no phone and no reason', (t) async {
    final r = await pumpStaff(
      t,
      location: '/staff/exports',
      overrides: [
        staffCsvSaverProvider.overrideWithValue((name, bytes) async {}),
      ],
    );
    await t.tap(find.byKey(const Key('staff.export.download')));
    await t.pumpAndSettle();
    expect(r.api.lastExport, containsPair('includePhone', 'false'));
    expect(r.api.lastExport!.containsKey('reason'), isFalse);
    await t.pump(SaartheeMotion.toastHold);
    await t.pumpAndSettle();
  });
}
