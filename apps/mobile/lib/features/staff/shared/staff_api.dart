import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/app_error.dart';
import '../shell/staff_session.dart';

typedef Json = Map<String, dynamic>;

/// TASK-10 staff console API (§5.3). The server enforces every role; the
/// email-session header is added here, the phone session by the interceptor.
class StaffApi {
  StaffApi(this._client, this._headers);

  final ApiClient _client;
  final Map<String, String>? _headers;

  Future<Json> _get(String path, [Map<String, dynamic>? query]) =>
      _client.getJson(path, query: query, headers: _headers);
  Future<Json> _post(String path, [Object? body]) => _client.postJson(
    path,
    body: body ?? const <String, dynamic>{},
    headers: _headers,
  );

  Future<Json> summary() => _get('/staff/summary');

  Future<Json> queue(String queue, {String? cursor}) => _get(
    '/staff/moderation',
    {'queue': queue, 'limit': 50, 'cursor': ?cursor},
  );

  Future<Json> issue(String id) => _get('/staff/issues/$id');
  Future<Json> mergeCandidates(String id) =>
      _get('/staff/issues/$id/merge-candidates');
  Future<Json> reviewed(String id) => _post('/staff/issues/$id/reviewed');
  Future<Json> reject(String id, String reason, String? note) => _post(
    '/staff/issues/$id/reject',
    {'reason': reason, if (note != null && note.isNotEmpty) 'note': note},
  );
  Future<Json> merge(String id, String targetId) =>
      _post('/staff/issues/$id/merge', {'targetIssueId': targetId});
  Future<Json> recategorise(String id, {String? categoryId, String? wardId}) =>
      _post('/staff/issues/$id/recategorise', {
        'categoryId': ?categoryId,
        'wardId': ?wardId,
      });
  Future<Json> hide(String id, String reason, {bool hidden = true}) => _post(
    '/staff/issues/$id/${hidden ? 'hide' : 'unhide'}',
    {'reason': reason},
  );

  /// Acknowledge / in progress / mark fixed (`/staff/issues/{id}/status`, backed by TASK-06 transition()).
  Future<Json> status(
    String id,
    String to, {
    String? note,
    List<String> photoIds = const [],
    String? expectedStatus,
  }) => _post('/staff/issues/$id/status', {
    'to': to,
    if (note != null && note.isNotEmpty) 'note': note,
    if (photoIds.isNotEmpty) 'photoIds': photoIds,
    'expectedStatus': ?expectedStatus,
  });

  Future<Json> hideComment(String eventId, String reason) =>
      _post('/staff/comments/$eventId/hide', {'reason': reason});
  Future<Json> resolveFlag(String flagId, String outcome) =>
      _post('/staff/flags/$flagId/resolve', {'outcome': outcome});

  Future<Json> users({String? q, String? cursor}) => _get('/staff/users', {
    if (q != null && q.isNotEmpty) 'q': q,
    'cursor': ?cursor,
  });
  Future<Json> setRole(String userId, String role) =>
      _post('/staff/users/$userId/role', {'role': role});
  Future<Json> suspend(String userId, String reason, {bool suspend = true}) =>
      _post('/staff/users/$userId/${suspend ? 'suspend' : 'unsuspend'}', {
        'reason': reason,
      });

  Future<Json> categories() => _get('/staff/categories');
  Future<Json> patchCategory(String id, Json body) =>
      _client.patchJson('/staff/categories/$id', body: body, headers: _headers);

  Future<Json> settings() => _get('/staff/settings');
  Future<Json> putSetting(String key, Object value) => _client.putJson(
    '/staff/settings/$key',
    body: {'value': value},
    headers: _headers,
  );

  /// After photo for "Mark as fixed": `POST /photos` from bytes (works on the
  /// web build too). Needs the phone session (the endpoint is citizen-auth).
  /// `purpose: after` + `issueId`, as TASK-06's transition() accepts only
  /// after-purpose photos when marking fixed (W-INT10).
  Future<String> uploadPhoto(String issueId, List<int> bytes) async {
    try {
      final res = await _client.dio.post<dynamic>(
        '/photos',
        data: FormData.fromMap({
          'purpose': 'after',
          'issueId': issueId,
          'photo': MultipartFile.fromBytes(
            bytes,
            filename: 'after.jpg',
            contentType: DioMediaType('image', 'jpeg'),
          ),
        }),
        options: Options(
          headers: _headers,
          sendTimeout: kUploadTimeout,
          receiveTimeout: kUploadTimeout,
        ),
      );
      return '${(res.data as Map)['photoId']}';
    } catch (e) {
      throw AppError.from(e);
    }
  }

  /// CSV bytes for `/staff/export`.
  Future<List<int>> export(Map<String, String> query) =>
      _client.getBytes('/staff/export', query: query, headers: _headers);
}

final staffApiProvider = Provider<StaffApi>(
  (ref) => StaffApi(
    ref.watch(apiClientProvider),
    ref.watch(staffAuthHeadersProvider),
  ),
);
