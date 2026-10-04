import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/api/api_client.dart';
import '../shell/staff_session.dart';
import 'ward_dashboard_models.dart';

/// TASK-11 representative console + claim review API. Scope and roles are
/// enforced by the server; this only adds the staff email-session header.
class RepConsoleApi {
  RepConsoleApi(this._c, this._h);

  final ApiClient _c;
  final Map<String, String>? _h;

  Future<Json> _get(String p, [Map<String, dynamic>? q]) =>
      _c.getJson(p, query: q, headers: _h);
  Future<Json> _post(String p, Object body) =>
      _c.postJson(p, body: body, headers: _h);

  Future<List<ScopeWard>> scope() async => [
    for (final w in ((await _get('/staff/ward/scope'))['items'] as List))
      ScopeWard.fromJson(w as Json),
  ];

  Future<WardDashboard> dashboard(String wardId) async =>
      WardDashboard.fromJson(
        await _get('/staff/ward-dashboard', {'ward': wardId}),
      );

  Future<List<int>> csv(String wardId, String from, String to) => _c.getBytes(
    '/staff/ward-dashboard/export',
    query: {'ward': wardId, 'from': from, 'to': to},
    headers: _h,
  );

  Future<Json> wardIssues(
    String wardId, {
    String? status,
    bool overdue = false,
  }) => _get('/staff/ward/issues', {
    'ward': wardId,
    'limit': 50,
    'status': ?status,
    if (overdue) 'overdue': 'true',
  });

  /// TASK-06 `POST /issues/{id}/status` (acknowledge / mark fixed).
  Future<Json> status(
    String issueId,
    String to,
    String expected, {
    String? note,
  }) => _post('/issues/$issueId/status', {
    'to': to,
    'expectedStatus': expected,
    'clientActionId': const Uuid().v4(),
    if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
  });

  Future<Json> comment(String issueId, String note) =>
      _post('/staff/issues/$issueId/comments', {'note': note});

  Future<Json> claims(String? status) =>
      _get('/staff/rep-claims', {'status': ?status});
  Future<Json> claim(String id) => _get('/staff/rep-claims/$id');
  Future<List<int>> evidence(String claimId, String photoId) =>
      _c.getBytes('/staff/rep-claims/$claimId/evidence/$photoId', headers: _h);
  Future<Json> approve(String id, String method) => _post(
    '/staff/rep-claims/$id/decide',
    {'decision': 'approve', 'method': method},
  );
  Future<Json> reject(String id, String reason) => _post(
    '/staff/rep-claims/$id/decide',
    {'decision': 'reject', 'reason': reason},
  );
  Future<Json> revoke(String repId, String reason) => _post(
    '/staff/representatives/$repId/revoke-verification',
    {'reason': reason},
  );

  Future<Json> messages() => _get('/staff/rep-messages');
  Future<Json> message(String id) => _get('/staff/rep-messages/$id');
  Future<Json> reply(String id, String body) =>
      _post('/staff/rep-messages/$id/reply', {'body': body});
}

final repConsoleApiProvider = Provider<RepConsoleApi>(
  (ref) => RepConsoleApi(
    ref.watch(apiClientProvider),
    ref.watch(staffAuthHeadersProvider),
  ),
);
