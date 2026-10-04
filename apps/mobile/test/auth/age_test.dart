// T-04-19 (AC-4): new accounts confirm age; "No" → blocked + Firebase
// signed out, nothing stored; consent box gates "Create account".
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/features/auth/application/session_controller.dart';
import 'package:saarthee/features/auth/presentation/age_screen.dart';
import 'package:saarthee/features/auth/presentation/blocked_screen.dart';

import 'fakes.dart';
import 'harness.dart';

Future<void> reachAge(WidgetTester t) async {
  await t.tap(find.byKey(const Key('h.follow')));
  await t.pumpAndSettle();
  await t.enterText(find.byKey(const Key('signIn.phone')), testPhoneDigits);
  await t.tap(find.byKey(const Key('signIn.send')));
  await t.pumpAndSettle();
  await t.enterText(find.byKey(const Key('otp.code')), testCode);
  await t.tap(find.byKey(const Key('otp.verify')));
  await t.pumpAndSettle();
}

bool createEnabled(WidgetTester t) =>
    t
        .widget<FilledButton>(
          find.descendant(
            of: find.byKey(const Key('age.create')),
            matching: find.byType(FilledButton),
          ),
        )
        .onPressed !=
    null;

void main() {
  testWidgets('"No" → blocked screen, Firebase signed out, nothing stored', (
    t,
  ) async {
    final gw = FakeAuthGateway();
    final api = FakeAccountApi()..newAccount = true;
    final (container, _) = await pumpAuthHarness(
      t,
      overrides: authOverrides(gateway: gw, api: api),
    );
    await reachAge(t);
    expect(find.byType(AgeScreen), findsOneWidget);
    expect(find.text('Are you 18 or older?'), findsWidgets);

    await t.tap(find.byKey(const Key('age.no')));
    await t.pumpAndSettle();
    expect(find.byType(BlockedScreen), findsOneWidget);
    expect(
      find.text(
        'Sorry, you need to be 18 or older to have an account. You can still browse issues, alerts and services.',
      ),
      findsOneWidget,
    );
    expect(gw.signOuts, 1);
    expect(api.calls, ['exchange(age=false)']);

    await t.tap(find.byKey(const Key('blocked.back')));
    await t.pumpAndSettle();
    expect(find.text('typed:0 followed:0'), findsOneWidget);
    expect(container.read(sessionProvider).signedIn, isFalse);
  });

  testWidgets('consent box gates "Create account"; yes + tick creates it', (
    t,
  ) async {
    final api = FakeAccountApi()..newAccount = true;
    final (container, _) = await pumpAuthHarness(
      t,
      overrides: authOverrides(gateway: FakeAuthGateway(), api: api),
    );
    await reachAge(t);
    expect(createEnabled(t), isFalse);
    await t.tap(find.byKey(const Key('age.yes')));
    await t.pump();
    expect(createEnabled(t), isFalse, reason: 'consent not ticked');
    await t.tap(find.byKey(const Key('age.consent')));
    await t.pump();
    expect(createEnabled(t), isTrue);

    await t.tap(find.byKey(const Key('age.create')));
    await t.pumpAndSettle();
    expect(api.calls, ['exchange(age=false)', 'exchange(age=true)']);
    expect(find.text('typed:0 followed:1'), findsOneWidget);
    expect(container.read(sessionProvider).signedIn, isTrue);
  });

  testWidgets('privacy notice opens in a sheet', (t) async {
    final api = FakeAccountApi()..newAccount = true;
    await pumpAuthHarness(
      t,
      overrides: authOverrides(gateway: FakeAuthGateway(), api: api),
    );
    await reachAge(t);
    await t.tap(find.byKey(const Key('age.privacyNotice')));
    await t.pumpAndSettle();
    expect(
      find.textContaining('Your name and number are never shown publicly'),
      findsOneWidget,
    );
  });
}
