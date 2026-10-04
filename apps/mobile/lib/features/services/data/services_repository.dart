import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/app_error.dart';
import '../../../core/settings/app_settings.dart';
import 'service_models.dart';

/// A response plus whether it came from the on-device cache (offline).
class Cached<T> {
  const Cached(this.value, {required this.fromCache});

  final T value;
  final bool fromCache;
}

/// TASK-12 prefs keys (feature-owned).
class ServicesPrefKeys {
  const ServicesPrefKeys._();

  static const servicesCache = 'v2.servicesCache';
  static const tipsCache = 'v2.tipsCache';
  static const dismissedTips = 'v2.dismissedTips';
}

/// AMC services directory API (TASK-12 §5.3). Lists are cached on device
/// (last good response) so the directory still opens offline.
abstract interface class ServicesRepository {
  Future<Cached<List<ServiceSummary>>> listServices();
  Future<ServiceDetail> getService(String slug, {String? wardId});
  Future<Cached<List<ServiceTip>>> tips({String? wardId});
}

class HttpServicesRepository implements ServicesRepository {
  HttpServicesRepository(this._client, this._prefs);

  final ApiClient _client;
  final SharedPreferences _prefs;

  List<Map<String, dynamic>> _items(Map<String, dynamic> body) =>
      ((body['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();

  Future<Cached<List<T>>> _cached<T>(
    String key,
    Future<Map<String, dynamic>> Function() fetch,
    T Function(Map<String, dynamic>) parse,
  ) async {
    try {
      final body = await fetch();
      await _prefs.setString(key, jsonEncode(body));
      return Cached(_items(body).map(parse).toList(), fromCache: false);
    } on AppError catch (e) {
      final raw = _prefs.getString(key);
      if (!e.isOffline || raw == null) rethrow;
      final body = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return Cached(_items(body).map(parse).toList(), fromCache: true);
    }
  }

  @override
  Future<Cached<List<ServiceSummary>>> listServices() => _cached(
    ServicesPrefKeys.servicesCache,
    () => _client.getJson('/services'),
    ServiceSummary.fromJson,
  );

  @override
  Future<ServiceDetail> getService(String slug, {String? wardId}) async =>
      ServiceDetail.fromJson(
        await _client.getJson(
          '/services/${Uri.encodeComponent(slug)}',
          query: {'ward': ?wardId},
        ),
      );

  @override
  Future<Cached<List<ServiceTip>>> tips({String? wardId}) => _cached(
    ServicesPrefKeys.tipsCache,
    () => _client.getJson('/services/tips', query: {'ward': ?wardId}),
    ServiceTip.fromJson,
  );
}

final servicesRepositoryProvider = Provider<ServicesRepository>(
  (ref) => HttpServicesRepository(
    ref.watch(apiClientProvider),
    ref.watch(sharedPreferencesProvider),
  ),
);
