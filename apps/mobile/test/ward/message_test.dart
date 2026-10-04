// W-09-03 message form (AC-4, AC-5, AC-6) and the "Message sent" toast part
// of W-09-06 (AC-13, AC-15).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/api/app_error.dart';
import 'package:saarthee/core/motion/motion_check.dart';
import 'package:saarthee/core/theme/motion.dart';

import '../helpers/fake_haptics.dart';
import 'ward_fakes.dart';

const _ms = Duration(milliseconds: 1);

Future<void> _fill(
  WidgetTester t, {
  String subject = 'Streetlight out',
  String body = 'The light near the temple is off.',
}) async {
  await t.enterText(find.byKey(const Key('relay.subject')), subject);
  await t.enterText(find.byKey(const Key('relay.body')), body);
  await t.pump();
}

Future<void> _send(WidgetTester t) async {
  await t.scrollUntilVisible(
    find.byKey(const Key('relay.send')),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await t.pumpAndSettle();
  await t.tap(find.byKey(const Key('relay.send')));
}

double _checkProgress(WidgetTester t) {
  final paint = t.widget<CustomPaint>(
    find.descendant(
      of: find.byType(MotionCheck),
      matching: find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is CheckPainter,
      ),
    ),
  );
  return (paint.painter! as CheckPainter).progress;
}

void main() {
  group('W-09-03 message form', () {
    testWidgets('counter, phone opt-in unticked, field rules, issue prefill', (
      t,
    ) async {
      final api = FakeWardApi();
      await pumpWardRoutes(
        t,
        api: api,
        initial: '/representatives/c0/message?issueId=i-1',
      );
      await t.pumpAndSettle();
      expect(find.text('Message Sample Corporator A'), findsWidgets);
      expect(find.byKey(const Key('relay.issue')), findsOneWidget);
      final box = t.widget<CheckboxListTile>(
        find.byKey(const Key('relay.sharePhone')),
      );
      expect(box.value, isFalse);
      expect(find.text('0/1000'), findsOneWidget);
      await _fill(t, subject: 'Hi', body: 'short');
      expect(find.text('5/1000'), findsOneWidget);
      await _send(t);
      await t.pumpAndSettle();
      expect(
        find.text('Write a subject of at least 3 characters.'),
        findsOneWidget,
      );
      expect(find.text('Write at least 10 characters.'), findsOneWidget);
      expect(api.sent, isEmpty);
      await t.enterText(find.byKey(const Key('relay.body')), 'x' * 1200);
      await t.pump();
      expect(find.text('1000/1000'), findsOneWidget);
    });

    final cases = <String, (AppError, String)>{
      'rate per representative': (
        const AppError(
          code: 'RATE_LIMITED',
          details: [AppErrorDetail(field: 'scope', issue: 'representative')],
        ),
        "You've sent 5 messages to this representative today. You can send more tomorrow.",
      ),
      'rate per day': (
        const AppError(
          code: 'RATE_LIMITED',
          details: [AppErrorDetail(field: 'scope', issue: 'daily')],
        ),
        "You've sent the most messages allowed today. You can send more tomorrow.",
      ),
      'language': (
        const AppError(code: 'MESSAGE_LANGUAGE'),
        "Your message contains words we can't send. Please edit it and try again.",
      ),
      'no contact': (
        const AppError(code: 'REP_NO_CONTACT'),
        "We don't have an official email for this representative yet.",
      ),
      'offline': (
        const AppError.offline(),
        "You're offline. Your message hasn't been sent.",
      ),
    };
    for (final e in cases.entries) {
      testWidgets('error copy: ${e.key}; text and clientMessageId kept', (
        t,
      ) async {
        final api = FakeWardApi()..sendErrors.add(e.value.$1);
        await pumpWardRoutes(
          t,
          api: api,
          initial: '/representatives/c0/message',
        );
        await t.pumpAndSettle();
        await _fill(t);
        await _send(t);
        await t.pumpAndSettle();
        expect(find.text(e.value.$2), findsOneWidget);
        expect(find.text('Streetlight out'), findsOneWidget);
        await _send(t);
        await t.pumpAndSettle();
        expect(api.sent, hasLength(2));
        expect(api.sent[1].clientMessageId, api.sent[0].clientMessageId);
      });
    }

    testWidgets('no consent → consent sheet → grant → send', (t) async {
      final api = FakeWardApi();
      final consent = FakeRelayConsent(granted: false);
      await pumpWardRoutes(
        t,
        api: api,
        consent: consent,
        initial: '/representatives/c0/message',
      );
      await t.pumpAndSettle();
      await _fill(t);
      await _send(t);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('relay.consentSheet')), findsOneWidget);
      expect(api.sent, isEmpty);
      await t.tap(find.byKey(const Key('relay.consentAgree')));
      await t.pumpAndSettle();
      expect(consent.grants, 1);
      expect(api.sent, hasLength(1));
      expect(api.sent.single.sharePhone, isFalse);
      await t.pump(const Duration(seconds: 5));
      await t.pumpAndSettle();
    });

    testWidgets(
      'server CONSENT_REQUIRED also opens the sheet; "Not now" sends nothing more',
      (t) async {
        final api = FakeWardApi()
          ..sendErrors.add(const AppError(code: 'CONSENT_REQUIRED'));
        await pumpWardRoutes(
          t,
          api: api,
          initial: '/representatives/c0/message',
        );
        await t.pumpAndSettle();
        await _fill(t);
        await _send(t);
        await t.pumpAndSettle();
        expect(find.byKey(const Key('relay.consentSheet')), findsOneWidget);
        await t.tap(find.text('Not now'));
        await t.pumpAndSettle();
        expect(api.sent, hasLength(1));
      },
    );
  });

  group('W-09-06 "Message sent" toast', () {
    testWidgets(
      'back on the profile: toast at rest after springIn, check drawn after its delay, one success haptic, announced',
      (t) async {
        final haptics = FakeSaartheeHaptics();
        final api = FakeWardApi();
        final r = await pumpWardRoutes(
          t,
          api: api,
          haptics: haptics,
          initial: '/representatives/c0',
        );
        await t.pumpAndSettle();
        r.router.push('/representatives/c0/message');
        await t.pumpAndSettle();
        await _fill(t);
        await t.tap(find.byKey(const Key('relay.sharePhone')));
        await _send(t);
        await t.pump();
        expect(api.sent.single.sharePhone, isTrue);
        expect(haptics.calls.where((c) => c == 'success'), hasLength(1));
        const text =
            "Message sent. We've emailed it to Sample Corporator A's office.";
        expect(find.text(text), findsOneWidget);
        expect(_checkProgress(t), 0);
        await t.pump(SaartheeMotion.drawCheckDelay - _ms);
        expect(_checkProgress(t), 0);
        await t.pump(SaartheeMotion.springIn.duration);
        await t.pump(SaartheeMotion.drawCheck.duration);
        expect(_checkProgress(t), 1);
        await t.pumpAndSettle(const Duration(milliseconds: 50));
        // Back on the profile.
        expect(find.byKey(const Key('rep.messageButton')), findsOneWidget);
        expect(find.byKey(const Key('relay.send')), findsNothing);
        await t.pump(const Duration(seconds: 5));
        await t.pumpAndSettle();
        expect(find.text(text), findsNothing);
      },
    );

    testWidgets(
      'reduced motion: one pump shows the toast with its full check',
      (t) async {
        final api = FakeWardApi();
        await pumpWardRoutes(
          t,
          api: api,
          reduced: true,
          initial: '/representatives/c0/message',
        );
        await t.pumpAndSettle();
        await _fill(t);
        await _send(t);
        await t.pump();
        await t.pump();
        expect(
          find.text(
            "Message sent. We've emailed it to Sample Corporator A's office.",
          ),
          findsOneWidget,
        );
        expect(_checkProgress(t), 1);
        await t.pump(const Duration(seconds: 5));
        await t.pumpAndSettle();
      },
    );
  });
}
