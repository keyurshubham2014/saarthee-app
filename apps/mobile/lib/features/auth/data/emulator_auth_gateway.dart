import 'package:dio/dio.dart';

import 'auth_gateway.dart';
import 'secure_store.dart';

/// Firebase Auth Emulator over its Identity Toolkit / Secure Token REST API
/// (no Firebase SDK, no `google-services.json`). Start the emulator with
/// `npx firebase-tools emulators:start --only auth --project demo-saarthee`
/// (docs/v2/firebase-setup.md). The refresh token lives in secure storage so
/// the Firebase user survives restarts, like the SDK.
class EmulatorAuthGateway implements AuthGateway {
  EmulatorAuthGateway({required String host, required this.store, Dio? dio})
    : _dio = dio ?? Dio(BaseOptions(baseUrl: 'http://$host'));

  final SecureStore store;
  final Dio _dio;

  /// Any key works on the emulator.
  static const _key = 'demo-key';

  String? _idToken;

  @override
  bool get isConfigured => true;

  Future<Map<String, dynamic>> _post(String path, Object body) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        path,
        queryParameters: {'key': _key},
        data: body,
      );
      return res.data ?? const {};
    } on DioException catch (e) {
      throw AuthGatewayException(_codeOf(e));
    }
  }

  static String _codeOf(DioException e) {
    final data = e.response?.data;
    final message = data is Map ? '${(data['error'] as Map?)?['message']}' : '';
    if (e.response == null) return AuthGatewayException.network;
    if (message.startsWith('INVALID_CODE')) {
      return AuthGatewayException.wrongCode;
    }
    if (message.startsWith('SESSION_EXPIRED') ||
        message.startsWith('CODE_EXPIRED') ||
        message.startsWith('INVALID_SESSION_INFO')) {
      return AuthGatewayException.expired;
    }
    if (message.startsWith('INVALID_PHONE_NUMBER')) {
      return AuthGatewayException.invalidPhone;
    }
    if (message.startsWith('TOO_MANY_ATTEMPTS') ||
        message.startsWith('QUOTA_EXCEEDED')) {
      return AuthGatewayException.tooManyRequests;
    }
    return AuthGatewayException.unavailable;
  }

  @override
  Future<String> sendCode(String phoneE164) async {
    final res = await _post(
      '/identitytoolkit.googleapis.com/v1/accounts:sendVerificationCode',
      {'phoneNumber': phoneE164, 'recaptchaToken': 'emulator'},
    );
    final session = res['sessionInfo'];
    if (session is! String) {
      throw const AuthGatewayException(AuthGatewayException.unavailable);
    }
    return session;
  }

  @override
  Future<FirebaseSignIn> verifyCode(String verificationId, String code) async {
    final res = await _post(
      '/identitytoolkit.googleapis.com/v1/accounts:signInWithPhoneNumber',
      {'sessionInfo': verificationId, 'code': code},
    );
    final idToken = res['idToken'];
    final uid = res['localId'];
    if (idToken is! String || uid is! String) {
      throw const AuthGatewayException(AuthGatewayException.unavailable);
    }
    _idToken = idToken;
    await store.write(
      SecureKeys.firebaseRefreshToken,
      res['refreshToken'] as String?,
    );
    await store.write(SecureKeys.firebaseUid, uid);
    return FirebaseSignIn(idToken: idToken, uid: uid);
  }

  @override
  Future<String?> idToken({bool forceRefresh = false}) async {
    if (_idToken != null && !forceRefresh) return _idToken;
    final refresh = await store.read(SecureKeys.firebaseRefreshToken);
    if (refresh == null) return null;
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/securetoken.googleapis.com/v1/token',
        queryParameters: {'key': _key},
        data: {'grant_type': 'refresh_token', 'refresh_token': refresh},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      _idToken = res.data?['id_token'] as String?;
      final next = res.data?['refresh_token'] as String?;
      if (next != null) await store.write(SecureKeys.firebaseRefreshToken, next);
      return _idToken;
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        await signOut();
        return null;
      }
      throw AuthGatewayException(_codeOf(e));
    }
  }

  @override
  Future<void> signOut() async {
    _idToken = null;
    await store.write(SecureKeys.firebaseRefreshToken, null);
    await store.write(SecureKeys.firebaseUid, null);
  }
}
