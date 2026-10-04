import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/app_error.dart';
import '../../../core/settings/app_settings.dart';
import '../../services/data/services_repository.dart' show Cached;
import 'initiative_models.dart';

/// Civic initiatives API (TASK-12 §5.3). The upcoming list is cached per
/// scope (ward or city) for offline viewing; RSVP calls need a session (the
/// session interceptor adds `Authorization`).
abstract interface class InitiativesRepository {
  Future<Cached<List<Initiative>>> list({String? wardId, int limit = 20});
  Future<Initiative> get(String id);
  Future<RsvpResult> rsvp(String id);
  Future<RsvpResult> cancelRsvp(String id);
}

class HttpInitiativesRepository implements InitiativesRepository {
  HttpInitiativesRepository(this._client, this._prefs);

  final ApiClient _client;
  final SharedPreferences _prefs;

  static String cacheKey(String? wardId) =>
      'v2.initiativesCache.${wardId ?? 'city'}';

  List<Initiative> _parse(Map<String, dynamic> body) =>
      ((body['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => Initiative.fromJson(Map<String, dynamic>.from(m)))
          .toList();

  @override
  Future<Cached<List<Initiative>>> list({
    String? wardId,
    int limit = 20,
  }) async {
    final key = cacheKey(wardId);
    try {
      final body = await _client.getJson(
        '/initiatives',
        query: {'upcoming': 'true', 'limit': '$limit', 'ward': ?wardId},
      );
      await _prefs.setString(key, jsonEncode(body));
      return Cached(_parse(body), fromCache: false);
    } on AppError catch (e) {
      final raw = _prefs.getString(key);
      if (!e.isOffline || raw == null) rethrow;
      return Cached(
        _parse(Map<String, dynamic>.from(jsonDecode(raw) as Map)),
        fromCache: true,
      );
    }
  }

  @override
  Future<Initiative> get(String id) async => Initiative.fromJson(
    await _client.getJson('/initiatives/${Uri.encodeComponent(id)}'),
  );

  @override
  Future<RsvpResult> rsvp(String id) async => RsvpResult.fromJson(
    await _client.postJson('/initiatives/${Uri.encodeComponent(id)}/rsvp'),
  );

  @override
  Future<RsvpResult> cancelRsvp(String id) async => RsvpResult.fromJson(
    await _client.deleteJson('/initiatives/${Uri.encodeComponent(id)}/rsvp'),
  );
}

final initiativesRepositoryProvider = Provider<InitiativesRepository>(
  (ref) => HttpInitiativesRepository(
    ref.watch(apiClientProvider),
    ref.watch(sharedPreferencesProvider),
  ),
);
