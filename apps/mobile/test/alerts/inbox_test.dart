// W-08-05 (AC-12) inbox: unread styling, mark all, signed out; W-08-08 (AC-17, AC-18) swipe-to-read + rolling badge.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/api/app_error.dart';
import 'package:saarthee/core/settings/app_settings.dart';
import 'package:saarthee/core/settings/motion_preference.dart';
import 'package:saarthee/core/theme/motion.dart';
import 'package:saarthee/core/wards/wards_repository.dart';
import 'package:saarthee/core/widgets/rolling_count.dart';
import 'package:saarthee/features/alerts/data/alerts_api.dart';
import 'package:saarthee/features/auth/application/session_controller.dart';
import 'package:saarthee/features/inbox/presentation/inbox_row.dart';

import '../helpers/app.dart';
import '../helpers/fake_wards.dart';
import 'alert_fakes.dart';

Future<FakeAlertsApi> _openInbox(
  WidgetTester t, {
  bool signedIn = true,
  bool reduced = false,
  FakeAlertsApi? api,
}) async {
  final fake = api ?? FakeAlertsApi();
  await pumpApp(
    t,
    prefs: {
      ...onboardedPrefs(),
      PrefKeys.homeWard: jsonEncode(paldi.toPrefsJson()),
    },
    overrides: [
      alertsApiProvider.overrideWithValue(fake),
      sessionProvider.overrideWith(() => FakeSession(signedIn: signedIn)),
      wardsRepositoryProvider.overrideWithValue(FakeWardsRepository()),
      if (reduced) reducedMotionProvider.overrideWithValue(true),
    ],
  );
  await t.tap(find.byKey(const Key('nav.3')));
  await t.pumpAndSettle();
  await t.tap(find.byKey(const ValueKey('inboxBell')));
  await t.pumpAndSettle();
  return fake;
}

FakeAlertsApi _three() => FakeAlertsApi()
  ..inboxItems = [
    inboxJson('n1'),
    inboxJson('n2', kind: 'issue_update'),
    inboxJson(
      'n3',
      kind: 'initiative',
      at: DateTime.now().toUtc().subtract(const Duration(days: 3)),
    ),
    inboxJson(
      'n4',
      read: true,
      at: DateTime.now().toUtc().subtract(const Duration(days: 4)),
    ),
  ];

double _dot(WidgetTester t, String id) =>
    t.widget<AnimatedOpacity>(find.byKey(ValueKey('inboxDot.$id'))).opacity;
String _badge(WidgetTester t) => t
    .widget<RollingCount>(
      find.descendant(
        of: find.byKey(const ValueKey('inboxBell')),
        matching: find.byType(RollingCount),
      ),
    )
    .value
    .toString();

void main() {
  testWidgets('signed out: sign-in prompt', (t) async {
    await _openInbox(t, signedIn: false);
    expect(
      find.text('Sign in to see updates about your reports and alerts.'),
      findsOneWidget,
    );
  });

  testWidgets('Today / Earlier groups, unread dots, mark all as read', (
    t,
  ) async {
    final api = await _openInbox(t, api: _three());
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Earlier'), findsOneWidget);
    expect(_dot(t, 'n1'), 1);
    expect(_dot(t, 'n4'), 0);
    await t.tap(find.byKey(const ValueKey('inboxMarkAll')));
    await t.pumpAndSettle();
    for (final id in ['n1', 'n2', 'n3']) {
      expect(_dot(t, id), 0);
    }
    expect(api.markCalls.last, isNull);
    expect(find.byKey(const ValueKey('inboxMarkAll')), findsNothing);
  });

  testWidgets(
    'swipe compresses and springs back, row stays, dot fades, badge rolls 3 → 2; TalkBack action',
    (t) async {
      final api = FakeAlertsApi()..inboxItems = _three().inboxItems;
      await pumpApp(
        t,
        prefs: {
          ...onboardedPrefs(),
          PrefKeys.homeWard: jsonEncode(paldi.toPrefsJson()),
        },
        overrides: [
          alertsApiProvider.overrideWithValue(api),
          sessionProvider.overrideWith(() => FakeSession()),
          wardsRepositoryProvider.overrideWithValue(FakeWardsRepository()),
        ],
      );
      await t.tap(find.byKey(const Key('nav.3')));
      await t.pumpAndSettle();
      expect(_badge(t), '3');
      await t.tap(find.byKey(const ValueKey('inboxBell')));
      await t.pumpAndSettle();
      await t.drag(
        find.byKey(const ValueKey('inboxRow.n1')),
        const Offset(-300, 0),
      );
      await t.pump();
      await t.pump(
        SaartheeMotion.short.duration,
      ); // Dismissible snaps back, then confirmDismiss.
      await t.pump(SaartheeMotion.instant.duration ~/ 2);
      final row = t.state<InboxRowState>(
        find.byKey(const ValueKey('inbox.n1')),
      );
      expect(row.compress.value, greaterThan(0));
      await t.pump(SaartheeMotion.instant.duration); // compress done
      await t.pump(SaartheeMotion.springIn.duration); // spring back done
      expect(row.compress.value, 0);
      expect(find.byKey(const ValueKey('inbox.n1')), findsOneWidget);
      expect(_dot(t, 'n1'), 0);
      expect(api.markCalls.last, ['n1']);

      // TalkBack "Mark as read" custom action on another row.
      final sem = t.widget<Semantics>(
        find
            .descendant(
              of: find.byKey(const ValueKey('inbox.n2')),
              matching: find.byType(Semantics),
            )
            .first,
      );
      final actions = sem.properties.customSemanticsActions!;
      expect(actions.keys.single.label, 'Mark as read');
      actions.values.single();
      await t.pumpAndSettle();
      expect(_dot(t, 'n2'), 0);
      await t.pageBack();
      await t.pumpAndSettle();
      expect(_badge(t), '1');
    },
  );

  testWidgets('failed update rolls back with a toast', (t) async {
    final api = _three()..markError = const AppError(code: 'INTERNAL_ERROR');
    await _openInbox(t, api: api);
    await t.drag(
      find.byKey(const ValueKey('inboxRow.n1')),
      const Offset(-300, 0),
    );
    await t.pump();
    await t.pump(SaartheeMotion.short.duration);
    expect(find.text("Couldn't update. Try again."), findsOneWidget);
    await t.pumpAndSettle();
    expect(_dot(t, 'n1'), 1);
  });

  testWidgets('reduced motion: one pump shows the final state, no compress', (
    t,
  ) async {
    await _openInbox(t, api: _three(), reduced: true);
    await t.drag(
      find.byKey(const ValueKey('inboxRow.n1')),
      const Offset(-300, 0),
    );
    await t.pump();
    final row = t.state<InboxRowState>(find.byKey(const ValueKey('inbox.n1')));
    expect(row.compress.value, 0);
    await t.pump();
    expect(_dot(t, 'n1'), 0);
  });
}
