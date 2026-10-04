import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/app_error.dart';
import '../../../core/api/error_messages.dart';
import '../../../core/l10n/app_localizations.dart';
import '../data/auth_gateway.dart';
import 'session_controller.dart';

/// Why sign-in was asked for (the reason line on `/sign-in`).
enum SignInReason {
  generic,
  report,
  meToo,
  follow,
  verify,
  message,
  rsvp,
  profile;

  static SignInReason parse(String? v) => SignInReason.values.firstWhere(
    (r) => r.name == v,
    orElse: () => SignInReason.generic,
  );

  String text(AppLocalizations l10n) => switch (this) {
    generic => l10n.authReasonGeneric,
    report => l10n.authReasonReport,
    meToo => l10n.authReasonMeToo,
    follow => l10n.authReasonFollow,
    verify => l10n.authReasonVerify,
    message => l10n.authReasonMessage,
    rsvp => l10n.authReasonRsvp,
    profile => l10n.authReasonProfile,
  };
}

@immutable
class PhoneSignInState {
  const PhoneSignInState({this.phoneE164, this.verificationId, this.idToken});

  final String? phoneE164;
  final String? verificationId;

  /// Firebase ID token kept between the OTP and age steps (memory only).
  final String? idToken;
}

/// Phone → OTP → (age) flow (TASK-04 §5.4).
class PhoneSignInController extends Notifier<PhoneSignInState> {
  @override
  PhoneSignInState build() => const PhoneSignInState();

  AuthGateway get _gateway => ref.read(authGatewayProvider);

  /// [tenDigits] is the validated 10-digit Indian number.
  Future<void> sendCode(String tenDigits) async {
    final phone = '+91$tenDigits';
    final id = await _gateway.sendCode(phone);
    state = PhoneSignInState(phoneE164: phone, verificationId: id);
  }

  Future<void> resend() async {
    final phone = state.phoneE164;
    if (phone == null) return;
    final id = await _gateway.sendCode(phone);
    state = PhoneSignInState(phoneE164: phone, verificationId: id);
  }

  /// Verifies the code and exchanges it for a session.
  Future<ExchangeOutcome> verify(String code) async {
    final id = state.verificationId;
    if (id == null) {
      throw const AuthGatewayException(AuthGatewayException.expired);
    }
    final fb = await _gateway.verifyCode(id, code);
    state = PhoneSignInState(
      phoneE164: state.phoneE164,
      verificationId: id,
      idToken: fb.idToken,
    );
    return ref.read(sessionProvider.notifier).exchange(fb.idToken);
  }

  /// "Yes, I am 18 or older" + consent ticked → creates the account.
  Future<void> confirmAge() async {
    final token =
        await _gateway.idToken() ??
        state.idToken ??
        (throw const AuthGatewayException(AuthGatewayException.expired));
    await ref
        .read(sessionProvider.notifier)
        .exchange(token, ageConfirmed: true);
    state = const PhoneSignInState();
  }

  /// "No" → Firebase signed out, nothing stored (AC-4).
  Future<void> declineAge() async {
    await _gateway.signOut();
    state = const PhoneSignInState();
  }

  void reset() => state = const PhoneSignInState();
}

final phoneSignInProvider =
    NotifierProvider<PhoneSignInController, PhoneSignInState>(
      PhoneSignInController.new,
    );

/// ARB text for any sign-in/account failure (gateway codes and API codes).
String authErrorText(AppLocalizations l10n, Object error) {
  if (error is AuthGatewayException) {
    return switch (error.code) {
      AuthGatewayException.invalidPhone => l10n.authPhoneInvalid,
      AuthGatewayException.tooManyRequests => l10n.authTooManyRequests,
      AuthGatewayException.wrongCode => l10n.authOtpWrong,
      AuthGatewayException.expired => l10n.authOtpExpired,
      AuthGatewayException.network => l10n.errorOffline,
      _ => l10n.authUnavailable,
    };
  }
  final e = AppError.from(error);
  return switch (e.code) {
    'AUTH_REQUIRED' => l10n.authReasonGeneric,
    'FIREBASE_TOKEN_INVALID' => l10n.authErrorTokenInvalid,
    'FIREBASE_UNAVAILABLE' => l10n.authUnavailable,
    'AGE_CONFIRMATION_REQUIRED' => l10n.authErrorAgeRequired,
    'CONSENT_REQUIRED' => l10n.authErrorConsentRequired,
    'CORE_CONSENT_REQUIRED' => l10n.authErrorCoreConsent,
    'ACCOUNT_SUSPENDED' => l10n.authErrorSuspended,
    'FORBIDDEN' => l10n.authErrorForbidden,
    'WARD_NOT_FOUND' => l10n.authErrorWardNotFound,
    _ => appErrorMessage(l10n, e),
  };
}
