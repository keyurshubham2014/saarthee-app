import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'emulator_auth_gateway.dart';
import 'secure_store.dart';

/// Firebase phone-auth boundary (TASK-04 §5.6 ASSUMPTION): the app talks to
/// Firebase Authentication only through this interface. Today it ships the
/// Auth Emulator implementation (Identity Toolkit REST, selected with
/// `--dart-define=AUTH_EMULATOR_HOST=10.0.2.2:9099`); the Firebase SDK
/// implementation is Deferred — needs Firebase project.
abstract interface class AuthGateway {
  /// False when no Firebase backend is configured for this build.
  bool get isConfigured;

  /// Sends the SMS code; returns the verification id for [verifyCode].
  Future<String> sendCode(String phoneE164);

  /// Confirms the code; the Firebase user stays signed in on this device.
  Future<FirebaseSignIn> verifyCode(String verificationId, String code);

  /// A Firebase ID token, refreshed when [forceRefresh] (silent re-exchange).
  /// Null when no Firebase user is signed in.
  Future<String?> idToken({bool forceRefresh = false});

  Future<void> signOut();
}

class FirebaseSignIn {
  const FirebaseSignIn({required this.idToken, required this.uid});

  final String idToken;
  final String uid;
}

/// Failure codes (mapped to ARB text by the screens). Never carries the
/// phone number, code or token.
class AuthGatewayException implements Exception {
  const AuthGatewayException(this.code);

  static const invalidPhone = 'invalid-phone-number';
  static const tooManyRequests = 'too-many-requests';
  static const wrongCode = 'invalid-verification-code';
  static const expired = 'session-expired';
  static const network = 'network';
  static const unavailable = 'unavailable';

  final String code;

  @override
  String toString() => 'AuthGatewayException($code)';
}

/// Used when the build has no Firebase backend: every call reports
/// `unavailable`, so the sign-in screen shows "Sign-in is unavailable".
class UnconfiguredAuthGateway implements AuthGateway {
  const UnconfiguredAuthGateway();

  @override
  bool get isConfigured => false;

  @override
  Future<String> sendCode(String phoneE164) =>
      Future.error(const AuthGatewayException(AuthGatewayException.unavailable));

  @override
  Future<FirebaseSignIn> verifyCode(String verificationId, String code) =>
      Future.error(const AuthGatewayException(AuthGatewayException.unavailable));

  @override
  Future<String?> idToken({bool forceRefresh = false}) async => null;

  @override
  Future<void> signOut() async {}
}

/// `--dart-define=AUTH_EMULATOR_HOST=host:port` selects the emulator.
const String kAuthEmulatorHost = String.fromEnvironment('AUTH_EMULATOR_HOST');

final authGatewayProvider = Provider<AuthGateway>((ref) {
  if (kAuthEmulatorHost.isEmpty) return const UnconfiguredAuthGateway();
  return EmulatorAuthGateway(
    host: kAuthEmulatorHost,
    store: ref.watch(secureStoreProvider),
  );
});
