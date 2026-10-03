import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'admin_api_error.dart';

/// Reads the current admin bearer token (null when signed out).
typedef AdminTokenReader = String? Function();

/// Called when an admin call comes back 401 `TOKEN_EXPIRED`/`TOKEN_REVOKED`.
typedef AdminSessionEndedCallback = void Function();

/// Thin HTTP wrapper for `/admin/*` calls.
///
/// Attaches `Authorization: Bearer` only to admin calls, converts failures
/// into [AdminApiError], and reports ended sessions through
/// [onSessionEnded]. Never logs headers, bodies or tokens.
class AdminApi {
  AdminApi({
    required this.dio,
    required this.readToken,
    required this.onSessionEnded,
  });

  final Dio dio;
  final AdminTokenReader readToken;
  final AdminSessionEndedCallback onSessionEnded;

  /// Base URL of the API, for building absolute links if needed.
  String get baseUrl => dio.options.baseUrl;

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final response = await _send<dynamic>(
      () => dio.get<dynamic>(path, queryParameters: query, options: _options()),
    );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Object? body,
    bool authenticated = true,
  }) async {
    final response = await _send<dynamic>(
      () => dio.post<dynamic>(
        path,
        data: body,
        options: _options(authenticated: authenticated),
      ),
      authenticated: authenticated,
    );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> patchJson(String path, {Object? body}) async {
    final response = await _send<dynamic>(
      () => dio.patch<dynamic>(path, data: body, options: _options()),
    );
    return _asMap(response.data);
  }

  /// Fetches binary content (photos) with the admin token.
  Future<Uint8List> getBytes(String path) async {
    final response = await _send<List<int>>(
      () => dio.get<List<int>>(
        path,
        options: _options(responseType: ResponseType.bytes),
      ),
    );
    final data = response.data;
    if (data == null) {
      throw const AdminApiError.unknown();
    }
    return Uint8List.fromList(data);
  }

  /// Fetches a text body (CSV export) and the response headers.
  Future<({String body, Headers headers})> getText(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final response = await _send<String>(
      () => dio.get<String>(
        path,
        queryParameters: query,
        options: _options(responseType: ResponseType.plain),
      ),
    );
    return (body: response.data ?? '', headers: response.headers);
  }

  Options _options({
    bool authenticated = true,
    ResponseType responseType = ResponseType.json,
  }) {
    final headers = <String, Object>{};
    if (authenticated) {
      final token = readToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return Options(headers: headers, responseType: responseType);
  }

  Future<Response<T>> _send<T>(
    Future<Response<T>> Function() call, {
    bool authenticated = true,
  }) async {
    try {
      return await call();
    } on DioException catch (e) {
      final error = mapDioException(e);
      if (authenticated && error.isSessionEnded) {
        onSessionEnded();
      } else if (authenticated && error.statusCode == 401) {
        // Any other 401 on an authenticated admin call also ends the session.
        onSessionEnded();
      }
      throw error;
    }
  }

  static Map<String, dynamic> _asMap(Object? data) {
    if (data == null || data == '') {
      return const <String, dynamic>{};
    }
    if (data is Map<String, dynamic>) {
      return data;
    }
    throw const AdminApiError.unknown();
  }
}

/// Converts a [DioException] into an [AdminApiError].
AdminApiError mapDioException(DioException e) {
  final inner = e.error;
  if (inner is AdminApiError) {
    return inner;
  }
  switch (e.type) {
    case DioExceptionType.connectionError:
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return const AdminApiError.network();
    case DioExceptionType.badResponse:
      return _fromResponse(e.response);
    case DioExceptionType.cancel:
    case DioExceptionType.badCertificate:
    case DioExceptionType.unknown:
      if (e.response != null) {
        return _fromResponse(e.response);
      }
      return const AdminApiError.network();
  }
}

AdminApiError _fromResponse(Response<dynamic>? response) {
  if (response == null) {
    return const AdminApiError.network();
  }
  final status = response.statusCode;
  String? code;
  final fieldErrors = <String, String>{};
  final data = response.data;
  final Object? body = data is List<int> ? null : data;
  if (body is Map && body['error'] is Map) {
    final error = body['error'] as Map;
    code = error['code'] as String?;
    final details = error['details'];
    if (details is List) {
      for (final item in details) {
        if (item is Map && item['field'] is String) {
          fieldErrors[item['field'] as String] =
              (item['issue'] ?? item['message'] ?? '').toString();
        }
      }
    }
  }
  int? retryAfter;
  final retryHeader = response.headers.value('retry-after');
  if (retryHeader != null) {
    retryAfter = int.tryParse(retryHeader.trim());
  }
  return AdminApiError(
    kind: AdminErrorKind.server,
    code: code ?? _codeForStatus(status),
    statusCode: status,
    retryAfterSeconds: retryAfter,
    fieldErrors: fieldErrors,
  );
}

String? _codeForStatus(int? status) {
  switch (status) {
    case 404:
      return AdminErrorCodes.notFound;
    case 410:
      return AdminErrorCodes.photoDeleted;
    case 429:
      return AdminErrorCodes.rateLimited;
    case 503:
      return AdminErrorCodes.serviceUnavailable;
    default:
      return status != null && status >= 500
          ? AdminErrorCodes.internalError
          : null;
  }
}
