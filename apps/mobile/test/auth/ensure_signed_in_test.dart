// T-04-17 (AC-1): ensureSignedIn — signed-in returns at once; signed-out
// pushes sign-in and resumes the caller with its state; cancel returns false.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/features/auth/application/ensure_signed_in.dart';
import 'package:saarthee/features/auth/application/session_controller.dart';
import 'package:saarthee/features/auth/presentation/sign_in_screen.dart';

import 'fakes.dart';
import 'harness.dart';

void main() {
  testWidgets('signed in → true without navigation', (t) async {
    final api = FakeAccountApi();
    await pumpAuthHarness(
      t,
      overrides: authOverrides(
        gateway: FakeAuthGateway(),
        api: api,
        signedIn: true,
      ),
    );
    await t.tap(find.byKey(const Key('h.follow')));
    await t.pumpAndSettle();
    expect(find.byType(SignInScreen), findsNothing);
    expect(find.text('typed:0 followed:1'), findsOneWidget);
  });

  testWidgets('signed out → sign-in, OTP, back to the caller with state', (
    t,
  ) async {
    final gw = FakeAuthGateway();
    final api = FakeAccountApi();
    final (container, _) = await pumpAuthHarness(
      t,
      overrides: authOverrides(gateway: gw, api: api),
    );
    await t.tap(find.byKey(const Key('h.type')));
    await t.pump();
    await t.tap(find.byKey(const Key('h.follow')));
    await t.pumpAndSettle();
    expect(find.byType(SignInScreen), findsOneWidget);
    expect(find.text('To follow an issue, please sign in.'), findsOneWidget);

    await t.enterText(find.byKey(const Key('signIn.phone')), testPhoneDigits);
    await t.tap(find.byKey(const Key('signIn.send')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('otp.code')), testCode);
    await t.tap(find.byKey(const Key('otp.verify')));
    await t.pumpAndSettle();

    expect(find.byType(SignInScreen), findsNothing);
    expect(find.text('typed:1 followed:1'), findsOneWidget);
    expect(container.read(sessionProvider).signedIn, isTrue);
    expect(api.calls, ['exchange(age=false)']);
    expect(gw.calls, ['send', 'verify']);
  });

  testWidgets('cancel on sign-in → false, action not done', (t) async {
    await pumpAuthHarness(
      t,
      overrides: authOverrides(
        gateway: FakeAuthGateway(),
        api: FakeAccountApi(),
      ),
    );
    await t.tap(find.byKey(const Key('h.follow')));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Back'));
    await t.pumpAndSettle();
    expect(find.byType(SignInScreen), findsNothing);
    expect(find.text('typed:0 followed:0'), findsOneWidget);
  });

  test('return path must be an in-app path', () {
    expect(safeReturnPath('/issues/abc'), '/issues/abc');
    expect(safeReturnPath('https://evil.example'), '/');
    expect(safeReturnPath('//evil.example'), '/');
    expect(safeReturnPath('/sign-in/otp'), '/');
    expect(safeReturnPath(null), '/');
    expect(
      signInLocation(from: '/me/privacy', reason: SignInReason.profile),
      '/sign-in?from=%2Fme%2Fprivacy&reason=profile',
    );
  });
}
