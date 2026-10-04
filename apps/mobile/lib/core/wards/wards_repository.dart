import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../api/app_error.dart';
import '../config/timings.dart';
import '../settings/app_settings.dart';
import '../settings/locale_controller.dart';
import 'ward.dart';

/// Why a ward lookup failed.
enum WardFailure { unavailable, outsideCity, notFound }

class WardException implements Exception {
  const WardException(this.failure);

  final WardFailure failure;

  @override
  String toString() => 'WardException($failure)';
}

/// Ward list with where it came from.
class WardsResult {
  const WardsResult(this.wards, {required this.fromCache});

  final List<Ward> wards;
  final bool fromCache;
}

/// Wards data access (TASK-03 §5.3): `GET /wards` and `GET /geo/locate`.
/// The only place to adapt if TASK-02's shapes differ. 8 s timeout, one
/// automatic retry on network errors, `Accept-Language` from the locale,
/// last good list cached as `v2.wardsCache`.
abstract interface class WardsRepository {
  Future<WardsResult> listWards();
  Future<WardLocateResult> locate(double lat, double lng);
}

class ApiWardsRepository implements WardsRepository {
  ApiWardsRepository({
    required this.dio,
    required this.prefs,
    required this.languageCode,
  });

  final Dio dio;
  final SharedPreferences prefs;
  final String languageCode;

  Options get _options => Options(
    headers: {'Accept-Language': languageCode},
    sendTimeout: AppTimings.wardsTimeout,
    receiveTimeout: AppTimings.wardsTimeout,
  );

  Future<Response<dynamic>> _get(
    String path, [
    Map<String, dynamic>? query,
  ]) async {
    try {
      return await dio.get<dynamic>(
        path,
        queryParameters: query,
        options: _options,
      );
    } on DioException catch (e) {
      if (AppError.from(e).isOffline) {
        await Future<void>.delayed(AppTimings.retryBackoff);
        return dio.get<dynamic>(
          path,
          queryParameters: query,
          options: _options,
        );
      }
      rethrow;
    }
  }

  @override
  Future<WardsResult> listWards() async {
    try {
      final res = await _get('/wards');
      final wards = parseWards(res.data);
      await prefs.setString(
        PrefKeys.wardsCache,
        jsonEncode({
          'fetchedAt': DateTime.now().toUtc().toIso8601String(),
          'items': [for (final w in wards) w.toJson()],
        }),
      );
      return WardsResult(wards, fromCache: false);
    } catch (_) {
      final cached = readCache(prefs);
      if (cached != null && cached.isNotEmpty) {
        return WardsResult(cached, fromCache: true);
      }
      throw const WardException(WardFailure.unavailable);
    }
  }

  @override
  Future<WardLocateResult> locate(double lat, double lng) async {
    try {
      final res = await _get('/geo/locate', {
        'lat': lat.toStringAsFixed(6),
        'lng': lng.toStringAsFixed(6),
      });
      final data = res.data;
      if (data is! Map<String, dynamic> || data['ward'] is! Map) {
        throw const WardException(WardFailure.notFound);
      }
      final wardJson = Map<String, dynamic>.from(data['ward'] as Map);
      if (wardJson['zone'] == null && data['zone'] is Map) {
        wardJson['zone'] = data['zone'];
      }
      return WardLocateResult(
        ward: Ward.fromJson(wardJson),
        confirm: data['confirm'] == true,
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 422) throw const WardException(WardFailure.outsideCity);
      if (status == 404) throw const WardException(WardFailure.notFound);
      throw const WardException(WardFailure.unavailable);
    }
  }

  static List<Ward> parseWards(Object? data) {
    final items = data is Map<String, dynamic> ? data['items'] : data;
    if (items is! List) throw const FormatException('wards: no items');
    return [
      for (final i in items)
        if (i is Map<String, dynamic>) Ward.fromJson(i),
    ]..sort((a, b) => a.number.compareTo(b.number));
  }

  static List<Ward>? readCache(SharedPreferences prefs) {
    final raw = prefs.getString(PrefKeys.wardsCache);
    if (raw == null) return null;
    try {
      return parseWards(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }
}

final wardsRepositoryProvider = Provider<WardsRepository>(
  (ref) => ApiWardsRepository(
    dio: ref.watch(dioProvider),
    prefs: ref.watch(sharedPreferencesProvider),
    languageCode: ref.watch(localeProvider).languageCode,
  ),
);
