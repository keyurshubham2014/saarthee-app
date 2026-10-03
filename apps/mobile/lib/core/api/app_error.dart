import 'package:dio/dio.dart';

/// A field-level problem returned in `error.details` (03 §2.1).
class AppErrorDetail {
  const AppErrorDetail({required this.field, required this.issue});

  final String field;
  final String issue;
}

/// Typed error for every failed API call. Screens map [code] to an ARB
/// message with `appErrorMessage` (core/api/error_messages.dart).
class AppError implements Exception {
  const AppError({
    required this.code,
    this.message = '',
    this.details = const [],
    this.requestId,
    this.retryAfter,
    this.statusCode,
  });

  /// Client-side codes (not sent by the backend).
  static const String offlineCode = 'OFFLINE';
  static const String timeoutCode = 'TIMEOUT';
  static const String unknownCode = 'INTERNAL_ERROR';

  const AppError.offline() : this(code: offlineCode);
  const AppError.timeout() : this(code: timeoutCode);

  /// Backend error code from 03 §9.1, or one of the client-side codes above.
  final String code;

  /// Safe server message; never shown directly (ARB is used instead).
  final String message;
  final List<AppErrorDetail> details;
  final String? requestId;

  /// Wait time from the `Retry-After` header on 429 responses.
  final Duration? retryAfter;
  final int? statusCode;

  bool get isOffline => code == offlineCode || code == timeoutCode;
  bool get isRateLimited => code == 'RATE_LIMITED';

  /// Converts any error thrown by dio (or elsewhere) into an [AppError].
  static AppError from(Object error) {
    if (error is AppError) return error;
    if (error is DioException) {
      final inner = error.error;
      if (inner is AppError) return inner;
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.transformTimeout:
          return const AppError.timeout();
        case DioExceptionType.connectionError:
          return const AppError.offline();
        case DioExceptionType.badResponse:
          return _fromResponse(error.response);
        case DioExceptionType.unknown:
          return error.response != null
              ? _fromResponse(error.response)
              : const AppError.offline();
        case DioExceptionType.cancel:
        case DioExceptionType.badCertificate:
          return const AppError(code: unknownCode);
      }
    }
    return const AppError(code: unknownCode);
  }

  static AppError _fromResponse(Response<dynamic>? response) {
    final status = response?.statusCode;
    Duration? retryAfter;
    final ra = response?.headers.value('retry-after');
    if (ra != null) {
      final secs = int.tryParse(ra.trim());
      if (secs != null) retryAfter = Duration(seconds: secs);
    }
    final data = response?.data;
    if (data is Map && data['error'] is Map) {
      final err = data['error'] as Map;
      final details = <AppErrorDetail>[];
      final raw = err['details'];
      if (raw is List) {
        for (final d in raw) {
          if (d is Map) {
            details.add(
              AppErrorDetail(
                field: '${d['field'] ?? ''}',
                issue: '${d['issue'] ?? ''}',
              ),
            );
          }
        }
      }
      return AppError(
        code: '${err['code'] ?? unknownCode}',
        message: '${err['message'] ?? ''}',
        details: details,
        requestId: err['requestId'] as String?,
        retryAfter: retryAfter,
        statusCode: status,
      );
    }
    final code = switch (status) {
      400 => 'VALIDATION_FAILED',
      404 => 'NOT_FOUND',
      429 => 'RATE_LIMITED',
      503 => 'SERVICE_UNAVAILABLE',
      _ => unknownCode,
    };
    return AppError(code: code, retryAfter: retryAfter, statusCode: status);
  }

  @override
  String toString() => 'AppError($code, status: $statusCode)';
}
