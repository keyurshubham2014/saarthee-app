import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';

/// Staff content endpoints (TASK-12 §5.3). Rows are plain JSON maps — the
/// staff screens only show and edit fields, so no typed models are needed.
/// The session interceptor adds `Authorization`; the server enforces roles.
abstract interface class StaffContentApi {
  Future<List<Map<String, dynamic>>> services({bool brokenOnly = false});
  Future<Map<String, dynamic>> createService(Map<String, Object?> body);
  Future<Map<String, dynamic>> updateService(
    String id,
    Map<String, Object?> body,
  );
  Future<void> deactivateService(String id);
  Future<Map<String, dynamic>> checkLink(String id);

  Future<List<Map<String, dynamic>>> initiatives();
  Future<Map<String, dynamic>> createInitiative(Map<String, Object?> body);
  Future<Map<String, dynamic>> updateInitiative(
    String id,
    Map<String, Object?> body,
  );
  Future<List<Map<String, dynamic>>> rsvps(String initiativeId);
  Future<int> markAttendance(
    String initiativeId,
    List<String> userIds,
    bool attended,
  );

  Future<List<Map<String, dynamic>>> tips();
  Future<Map<String, dynamic>> createTip(Map<String, Object?> body);
  Future<Map<String, dynamic>> updateTip(String id, Map<String, Object?> body);
  Future<void> deleteTip(String id);
}

class HttpStaffContentApi implements StaffContentApi {
  HttpStaffContentApi(this._c);

  final ApiClient _c;

  List<Map<String, dynamic>> _items(Map<String, dynamic> body) =>
      ((body['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();

  String _id(String id) => Uri.encodeComponent(id);

  @override
  Future<List<Map<String, dynamic>>> services({
    bool brokenOnly = false,
  }) async => _items(
    await _c.getJson(
      '/staff/services',
      query: {if (brokenOnly) 'linkOk': 'false'},
    ),
  );

  @override
  Future<Map<String, dynamic>> createService(Map<String, Object?> body) =>
      _c.postJson('/staff/services', body: body);

  @override
  Future<Map<String, dynamic>> updateService(
    String id,
    Map<String, Object?> body,
  ) => _c.patchJson('/staff/services/${_id(id)}', body: body);

  @override
  Future<void> deactivateService(String id) =>
      _c.deleteJson('/staff/services/${_id(id)}');

  @override
  Future<Map<String, dynamic>> checkLink(String id) =>
      _c.postJson('/staff/services/${_id(id)}/link-check');

  @override
  Future<List<Map<String, dynamic>>> initiatives() async =>
      _items(await _c.getJson('/staff/initiatives'));

  @override
  Future<Map<String, dynamic>> createInitiative(Map<String, Object?> body) =>
      _c.postJson('/staff/initiatives', body: body);

  @override
  Future<Map<String, dynamic>> updateInitiative(
    String id,
    Map<String, Object?> body,
  ) => _c.patchJson('/staff/initiatives/${_id(id)}', body: body);

  @override
  Future<List<Map<String, dynamic>>> rsvps(String initiativeId) async =>
      _items(await _c.getJson('/staff/initiatives/${_id(initiativeId)}/rsvps'));

  @override
  Future<int> markAttendance(
    String initiativeId,
    List<String> userIds,
    bool attended,
  ) async {
    final res = await _c.postJson(
      '/staff/initiatives/${_id(initiativeId)}/attendance',
      body: {'userIds': userIds, 'attended': attended},
    );
    return (res['updated'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<List<Map<String, dynamic>>> tips() async =>
      _items(await _c.getJson('/staff/tips'));

  @override
  Future<Map<String, dynamic>> createTip(Map<String, Object?> body) =>
      _c.postJson('/staff/tips', body: body);

  @override
  Future<Map<String, dynamic>> updateTip(
    String id,
    Map<String, Object?> body,
  ) => _c.patchJson('/staff/tips/${_id(id)}', body: body);

  @override
  Future<void> deleteTip(String id) => _c.deleteJson('/staff/tips/${_id(id)}');
}

final staffContentApiProvider = Provider<StaffContentApi>(
  (ref) => HttpStaffContentApi(ref.watch(apiClientProvider)),
);
