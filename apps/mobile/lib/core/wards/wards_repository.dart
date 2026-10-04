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

/// `422 OUTSIDE_SERVICE_AREA` from `/geo/locate`: a valid point that no
/// ward can be assigned to (TASK-02 §5.3).
class OutsideServiceArea extends WardException {
  const OutsideServiceArea() : super(WardFailure.outsideCity);

  static const code = 'OUTSIDE_SERVICE_AREA';
}

/// Ward list with where it came from.
class WardsResult {
  const WardsResult(
    this.wards, {
    required this.fromCache,
    this.boundaryVersion,
  });

  final List<Ward> wards;
  final bool fromCache;

  /// `boundaryVersion` of the list (null for caches written before v2.2).
  final String? boundaryVersion;
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
    final WardsResult fresh;
    try {
      final res = await _get('/wards');
      fresh = parseResult(res.data, fromCache: false);
      if (fresh.wards.isEmpty) throw const FormatException('wards: empty');
    } catch (_) {
      final cached = readCache(prefs);
      if (cached != null && cached.wards.isNotEmpty) return cached;
      throw const WardException(WardFailure.unavailable);
    }
    await _writeCacheIfChanged(fresh);
    return fresh;
  }

  /// `v2.wardsCache` = `{fetchedAt, boundaryVersion, items}`. Replaced when
  /// the API's `boundaryVersion` or any ward differs from what is stored.
  Future<void> _writeCacheIfChanged(WardsResult fresh) async {
    final items = [for (final w in fresh.wards) w.toJson()];
    final raw = prefs.getString(PrefKeys.wardsCache);
    if (raw != null) {
      try {
        final old = jsonDecode(raw) as Map<String, dynamic>;
        if (old['boundaryVersion'] == fresh.boundaryVersion &&
            jsonEncode(old['items']) == jsonEncode(items)) {
          return;
        }
      } catch (_) {
        // Unreadable cache: overwrite it below.
      }
    }
    await prefs.setString(
      PrefKeys.wardsCache,
      jsonEncode({
        'fetchedAt': DateTime.now().toUtc().toIso8601String(),
        'boundaryVersion': fresh.boundaryVersion,
        'items': items,
      }),
    );
  }

  @override
  Future<WardLocateResult> locate(double lat, double lng) async {
    final Response<dynamic> res;
    try {
      res = await _get('/geo/locate', {
        'lat': lat.toStringAsFixed(6),
        'lng': lng.toStringAsFixed(6),
      });
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 422 || AppError.from(e).code == OutsideServiceArea.code) {
        throw const OutsideServiceArea();
      }
      if (status == 404) throw const WardException(WardFailure.notFound);
      throw const WardException(WardFailure.unavailable);
    }
    final data = res.data;
    if (data is! Map<String, dynamic> || data['ward'] is! Map) {
      throw const WardException(WardFailure.notFound);
    }
    try {
      return WardLocateResult.fromJson(data);
    } catch (_) {
      throw const WardException(WardFailure.notFound);
    }
  }

  /// `{items:[WardSummary], boundaryVersion}` (or a bare list) → wards
  /// sorted by number.
  static WardsResult parseResult(Object? data, {required bool fromCache}) {
    final items = data is Map<String, dynamic> ? data['items'] : data;
    if (items is! List) throw const FormatException('wards: no items');
    final wards = [
      for (final i in items)
        if (i is Map) Ward.fromJson(Map<String, dynamic>.from(i)),
    ]..sort((a, b) => a.number.compareTo(b.number));
    final version = data is Map<String, dynamic>
        ? data['boundaryVersion'] as String?
        : null;
    return WardsResult(wards, fromCache: fromCache, boundaryVersion: version);
  }

  static List<Ward> parseWards(Object? data) =>
      parseResult(data, fromCache: false).wards;

  /// The cached list (`fromCache: true`), or null when absent/unreadable.
  static WardsResult? readCache(SharedPreferences prefs) {
    final raw = prefs.getString(PrefKeys.wardsCache);
    if (raw == null) return null;
    try {
      return parseResult(jsonDecode(raw), fromCache: true);
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
