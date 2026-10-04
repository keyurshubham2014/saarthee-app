import 'package:dio/dio.dart';

/// Adds the citizen session to API calls and renews it silently
/// (TASK-04 §5.4 "Session handling"):
/// - `Authorization: Bearer <session>` on every non-admin call that has none;
/// - 401 `TOKEN_EXPIRED` → [renew] (fresh Firebase ID token → `POST
///   /auth/firebase`) once, then the request is retried;
/// - 401 `TOKEN_REVOKED`, or a failed renewal → [onSignedOut].
/// Token values are never logged.
class SessionInterceptor extends Interceptor {
  SessionInterceptor({
    required this.dio,
    required this.currentToken,
    required this.renew,
    required this.onSignedOut,
  });

  final Dio dio;
  final String? Function() currentToken;

  /// Returns the new session token, or null when renewal is impossible.
  final Future<String?> Function() renew;
  final Future<void> Function() onSignedOut;

  static const _retried = 'saarthee.sessionRetried';
  Future<String?>? _renewing;

  static bool _skips(RequestOptions o) =>
      o.path.startsWith('/admin') || o.path == '/auth/firebase';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = currentToken();
    if (token != null &&
        !_skips(options) &&
        !options.headers.containsKey('Authorization')) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  static String? _code(Response<dynamic>? res) {
    final data = res?.data;
    if (data is Map && data['error'] is Map) {
      return (data['error'] as Map)['code'] as String?;
    }
    return null;
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    if (err.response?.statusCode != 401 || _skips(options)) {
      return handler.next(err);
    }
    final code = _code(err.response);
    if (code == 'TOKEN_REVOKED') {
      await onSignedOut();
      return handler.next(err);
    }
    if (code != 'TOKEN_EXPIRED' || options.extra[_retried] == true) {
      return handler.next(err);
    }
    final fresh = await (_renewing ??= renew().whenComplete(
      () => _renewing = null,
    ));
    if (fresh == null) {
      await onSignedOut();
      return handler.next(err);
    }
    options.extra[_retried] = true;
    options.headers['Authorization'] = 'Bearer $fresh';
    try {
      handler.resolve(await dio.fetch<dynamic>(options));
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}
