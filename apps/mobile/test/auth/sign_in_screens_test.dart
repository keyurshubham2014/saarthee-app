// T-04-18 (AC-1): phone validation, OTP wrong/expired messages, resend
// countdown, drawn check before the pop, instant with reduced motion.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/config/timings.dart';
import 'package:saarthee/core/motion/motion_check.dart';
import 'package:saarthee/core/theme/motion.dart';
import 'package:saarthee/features/auth/data/auth_gateway.dart';
import 'package:saarthee/features/auth/presentation/otp_screen.dart';
import 'package:saarthee/features/auth/presentation/sign_in_screen.dart';

import 'fakes.dart';
import 'harness.dart';

Future<void> openOtp(WidgetTester t) async {
  await t.tap(find.byKey(const Key('h.follow')));
  await t.pumpAndSettle();
  await t.enterText(find.byKey(const Key('signIn.phone')), testPhoneDigits);
  await t.tap(find.byKey(const Key('signIn.send')));
  await t.pumpAndSettle();
}

double checkProgress(WidgetTester t) {
  final paint = t.widget<CustomPaint>(
    find.descendant(
      of: find.byType(MotionCheck),
      matching: find.byType(CustomPaint),
    ),
  );
  return (paint.painter! as CheckPainter).progress;
}

void main() {
  testWidgets('invalid number → inline error, no code sent', (t) async {
    final gw = FakeAuthGateway();
    await pumpAuthHarness(
      t,
      overrides: authOverrides(gateway: gw, api: FakeAccountApi()),
    );
    await t.tap(find.byKey(const Key('h.follow')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('signIn.phone')), '12345');
    await t.tap(find.byKey(const Key('signIn.send')));
    await t.pumpAndSettle();
    expect(
      find.text('Enter a valid 10-digit Indian mobile number.'),
      findsOneWidget,
    );
    expect(gw.calls, isEmpty);
    expect(find.byType(SignInScreen), findsOneWidget);
  });

  testWidgets('too many requests → message', (t) async {
    final gw = _ThrottledGateway();
    await pumpAuthHarness(
      t,
      overrides: authOverrides(gateway: gw, api: FakeAccountApi()),
    );
    await openOtp(t);
    expect(
      find.text('Too many attempts. Please try again later.'),
      findsOneWidget,
    );
  });

  testWidgets('wrong and expired codes show their messages', (t) async {
    final gw = FakeAuthGateway();
    await pumpAuthHarness(
      t,
      overrides: authOverrides(gateway: gw, api: FakeAccountApi()),
    );
    await openOtp(t);
    expect(
      find.text('Enter the 6-digit code sent to +91 90000 00001'),
      findsOneWidget,
    );
    await t.enterText(find.byKey(const Key('otp.code')), '000000');
    await t.tap(find.byKey(const Key('otp.verify')));
    await t.pumpAndSettle();
    expect(
      find.text('That code is not right. Check the SMS and try again.'),
      findsOneWidget,
    );
    gw.verifyError = AuthGatewayException.expired;
    await t.tap(find.byKey(const Key('otp.verify')));
    await t.pumpAndSettle();
    expect(find.text('This code has expired. Send a new one.'), findsOneWidget);
  });

  testWidgets('resend unlocks after the 30 s countdown', (t) async {
    final gw = FakeAuthGateway();
    await pumpAuthHarness(
      t,
      overrides: authOverrides(gateway: gw, api: FakeAccountApi()),
    );
    await openOtp(t);
    expect(find.text('Resend code in 30 s'), findsOneWidget);
    await t.tap(find.byKey(const Key('otp.resend')));
    await t.pump();
    expect(gw.calls, ['send']);
    await t.pump(AppTimings.otpResendWait);
    await t.pump();
    expect(find.text('Resend code'), findsOneWidget);
    await t.tap(find.byKey(const Key('otp.resend')));
    await t.pumpAndSettle();
    expect(gw.calls, ['send', 'send']);
    expect(find.text('Resend code in 30 s'), findsOneWidget);
  });

  testWidgets('success: check fully drawn (+150 ms delay) before the pop', (
    t,
  ) async {
    await pumpAuthHarness(
      t,
      overrides: authOverrides(
        gateway: FakeAuthGateway(),
        api: FakeAccountApi(),
      ),
    );
    await openOtp(t);
    await t.enterText(find.byKey(const Key('otp.code')), testCode);
    await t.tap(find.byKey(const Key('otp.verify')));
    await t.pump();
    await t.pump();
    expect(find.byKey(const Key('auth.signedInCheck')), findsOneWidget);
    expect(find.text('Signed in'), findsOneWidget);
    expect(checkProgress(t), 0);
    await t.pump(SaartheeMotion.drawCheckDelay);
    await t.pump(
      SaartheeMotion.drawCheck.duration - const Duration(milliseconds: 1),
    );
    expect(
      find.byType(OtpScreen),
      findsOneWidget,
      reason: 'still waiting for the check',
    );
    await t.pump(const Duration(milliseconds: 1));
    expect(checkProgress(t), 1);
    await t.pumpAndSettle();
    expect(find.byType(OtpScreen), findsNothing);
    expect(find.text('typed:0 followed:1'), findsOneWidget);
  });

  testWidgets('reduced motion: check drawn at once, pop on the next frame', (
    t,
  ) async {
    t.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpAuthHarness(
      t,
      overrides: authOverrides(
        gateway: FakeAuthGateway(),
        api: FakeAccountApi(),
      ),
    );
    await openOtp(t);
    await t.enterText(find.byKey(const Key('otp.code')), testCode);
    await t.tap(find.byKey(const Key('otp.verify')));
    await t.pump();
    await t.pump();
    expect(checkProgress(t), 1);
    await t.pump(Duration.zero); // the zero-length wait for the check
    await t.pump(); // next frame: pop
    // The pop starts on the next frame (the route is no longer active);
    // the reduced-motion transition then fades out.
    expect(ModalRoute.of(t.element(find.byType(OtpScreen)))!.isActive, isFalse);
    await t.pumpAndSettle();
    expect(find.byType(OtpScreen), findsNothing);
    expect(find.text('typed:0 followed:1'), findsOneWidget);
  });
}

class _ThrottledGateway extends FakeAuthGateway {
  @override
  Future<String> sendCode(String phoneE164) => Future.error(
    const AuthGatewayException(AuthGatewayException.tooManyRequests),
  );
}
