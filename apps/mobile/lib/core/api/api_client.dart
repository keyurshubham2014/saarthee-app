import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import '../config/timings.dart';
import '../settings/app_settings.dart';
import 'app_error.dart';

/// Timeouts (02 §5.3): 15 s for JSON calls, 60 s for photo uploads.
const Duration kJsonTimeout = AppTimings.jsonTimeout;
const Duration kUploadTimeout = AppTimings.uploadTimeout;

/// Thin wrapper over dio. Every method throws [AppError] on failure.
///
/// Standard headers on every call (03 §2.1): `X-Install-Id`, `X-App-Version`,
/// `X-Platform`, and a fresh `X-Request-Id`. Callers add `Authorization`
/// per request through [headers]. Header values are never
/// logged.
class ApiClient {
  ApiClient(this.dio);

  final Dio dio;

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) => _run(
    () => dio.get<dynamic>(
      path,
      queryParameters: query,
      options: Options(headers: headers),
    ),
  );

  Future<Map<String, dynamic>> postJson(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) => _run(
    () => dio.post<dynamic>(
      path,
      data: body,
      options: Options(headers: headers),
    ),
  );

  Future<Map<String, dynamic>> patchJson(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) => _run(
    () => dio.patch<dynamic>(
      path,
      data: body,
      options: Options(headers: headers),
    ),
  );

  /// TASK-08 (subscriptions). Additive.
  Future<Map<String, dynamic>> putJson(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) => _run(
    () => dio.put<dynamic>(
      path,
      data: body,
      options: Options(headers: headers),
    ),
  );

  Future<Map<String, dynamic>> deleteJson(
    String path, {
    Map<String, String>? headers,
  }) =>
      _run(() => dio.delete<dynamic>(path, options: Options(headers: headers)));

  /// Raw bytes (photos, CSV). Throws [AppError] on failure.
  Future<List<int>> getBytes(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    try {
      final res = await dio.get<List<int>>(
        path,
        queryParameters: query,
        options: Options(headers: headers, responseType: ResponseType.bytes),
      );
      return res.data ?? const [];
    } catch (e) {
      throw AppError.from(e);
    }
  }

  /// Multipart upload with progress (0.0–1.0) and the 60 s timeout.
  Future<Map<String, dynamic>> uploadFile(
    String path, {
    required String filePath,
    String field = 'photo',
    String filename = 'photo.jpg',
    Map<String, String> fields = const {},
    Map<String, String>? headers,
    void Function(double progress)? onProgress,
  }) async {
    final form = FormData.fromMap({
      ...fields,
      field: await MultipartFile.fromFile(
        filePath,
        filename: filename,
        contentType: DioMediaType('image', 'jpeg'),
      ),
    });
    return _run(
      () => dio.post<dynamic>(
        path,
        data: form,
        options: Options(
          headers: headers,
          sendTimeout: kUploadTimeout,
          receiveTimeout: kUploadTimeout,
        ),
        onSendProgress: (sent, total) {
          if (total > 0 && onProgress != null) onProgress(sent / total);
        },
      ),
    );
  }

  Future<Map<String, dynamic>> _run(
    Future<Response<dynamic>> Function() call,
  ) async {
    try {
      final res = await call();
      final data = res.data;
      if (data is Map<String, dynamic>) return data;
      return <String, dynamic>{};
    } catch (e) {
      throw AppError.from(e);
    }
  }
}

String appPlatformName() {
  try {
    if (Platform.isIOS) return 'ios';
  } catch (_) {
    // Platform is unavailable on web; the app ships for Android/iOS only.
  }
  return 'android';
}

/// Configured dio: base URL, timeouts and standard headers.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: kJsonTimeout,
      sendTimeout: kJsonTimeout,
      receiveTimeout: kJsonTimeout,
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    ),
  );
  const uuid = Uuid();
  final platform = appPlatformName();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final settings = ref.read(appSettingsProvider);
        options.headers['X-Install-Id'] = settings.installId;
        options.headers['X-App-Version'] = AppConfig.appVersion;
        options.headers['X-Platform'] = platform;
        options.headers['X-Request-Id'] = uuid.v4();
        handler.next(options);
      },
    ),
  );
  return dio;
});

/// The app's single API client (02 §5.3). Admin features may add an auth
/// interceptor to `ref.read(apiClientProvider).dio` or pass `Authorization`
/// per call via `headers`.
final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(dioProvider)),
);
