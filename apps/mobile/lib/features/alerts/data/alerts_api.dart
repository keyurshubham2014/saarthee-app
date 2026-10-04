import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../inbox/data/inbox_models.dart';
import 'alert_models.dart';

/// Alerts, subscriptions and inbox endpoints (TASK-08 §5.3). The session
/// interceptor adds the Bearer token when signed in.
class AlertsApi {
  AlertsApi(this._api);

  final ApiClient _api;

  /// Raw `GET /alerts` items (the caller caches the JSON for offline use).
  Future<List<Map<String, dynamic>>> listRaw({
    required List<String> wardIds,
    required bool active,
  }) async {
    final j = await _api.getJson(
      '/alerts',
      query: {
        'wards': wardIds.take(6).join(','),
        'active': '$active',
        'limit': '50',
      },
    );
    return [
      for (final a in (j['items'] as List? ?? const []))
        (a as Map).cast<String, dynamic>(),
    ];
  }

  /// Raw `GET /alerts/{id}`.
  Future<Map<String, dynamic>> detailRaw(String id) =>
      _api.getJson('/alerts/$id');

  Future<AlertSubscriptions> mySubscriptions() async =>
      AlertSubscriptions.fromJson(await _api.getJson('/me/subscriptions'));

  Future<AlertSubscriptions> putMySubscriptions(AlertSubscriptions s) async =>
      AlertSubscriptions.fromJson(
        await _api.putJson('/me/subscriptions', body: s.toJson()),
      );

  Future<AlertSubscriptions> deviceSubscriptions(String installId) async =>
      AlertSubscriptions.fromJson(
        await _api.getJson('/devices/$installId/subscriptions'),
      );

  Future<AlertSubscriptions> putDeviceSubscriptions(
    String installId,
    String? homeWardId,
    AlertSubscriptions s,
  ) async => AlertSubscriptions.fromJson(
    await _api.putJson(
      '/devices/$installId/subscriptions',
      body: {...s.toJson(), 'homeWardId': homeWardId},
    ),
  );

  Future<InboxPage> inbox({String? cursor}) async => InboxPage.fromJson(
    await _api.getJson(
      '/me/notifications',
      query: {'limit': '50', 'cursor': ?cursor},
    ),
  );

  /// Marks [ids] (or everything when null) read; returns the new unread count.
  Future<int> markRead({List<String>? ids}) async {
    final j = await _api.postJson(
      '/me/notifications/read',
      body: ids == null ? {'all': true} : {'ids': ids},
    );
    return (j['unreadCount'] as num?)?.toInt() ?? 0;
  }
}

final alertsApiProvider = Provider<AlertsApi>(
  (ref) => AlertsApi(ref.watch(apiClientProvider)),
);
