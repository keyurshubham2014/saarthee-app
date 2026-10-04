// TASK-11 fakes: a canned representative console API and the AC-6 fixture.
import 'package:saarthee/core/api/app_error.dart';
import 'package:saarthee/features/staff/ward_dashboard/rep_console_api.dart';
import 'package:saarthee/features/staff/ward_dashboard/ward_dashboard_models.dart';

const ward12 = {
  'id': 'w12',
  'number': 12,
  'nameEn': 'Navrangpura',
  'nameGu': 'નવરંગપુરા',
};
const ward13 = {
  'id': 'w13',
  'number': 13,
  'nameEn': 'Paldi',
  'nameGu': 'પાલડી',
};

/// AC-6 fixture: 9 open (3 / 4 / 2 by age), 3 overdue, 1 fixed, 1 verified.
Json dashboardJson(
  Map<String, Object> ward, {
  bool election = false,
  int open = 9,
}) => {
  'ward': ward,
  'generatedAt': '2026-10-03T10:00:00Z',
  'totals': {'open': open, 'overdue': 3, 'markedFixed30d': 1, 'verified30d': 1},
  'byCategory': [
    {'slug': 'roads', 'd0_7': 2, 'd8_30': 3, 'd31Plus': 2, 'total': 7},
    {'slug': 'water', 'd0_7': 1, 'd8_30': 1, 'd31Plus': 0, 'total': 2},
  ],
  'overdue': [
    {
      'issueId': 'i1',
      'title': 'Pothole near the school',
      'category': 'roads',
      'status': 'acknowledged',
      'ageDays': 15,
      'slaDueAt': '2026-10-01T00:00:00Z',
      'meTooCount': 2,
    },
  ],
  'hotspots': [
    {'lat': 23.0365, 'lng': 72.5611, 'count': 5},
  ],
  'trend': [
    for (var i = 0; i < 12; i++)
      {
        'weekStart': '2026-07-${(i + 10).toString().padLeft(2, '0')}',
        'reported': i,
        'markedFixed': i == 11 ? 4 : i % 3,
        'verified': 1,
      },
  ],
  'electionMode': {'active': election, 'until': null},
};

class FakeRepConsoleApi implements RepConsoleApi {
  FakeRepConsoleApi({this.wards = const [ward12, ward13]});

  final List<Map<String, Object>> wards;
  final calls = <String>[];
  bool offline = false;
  bool election = false;
  int open = 9;
  Json issuesJson = {
    'items': <Json>[],
    'electionMode': {'active': false},
  };
  Json messagesJson = {'items': <Json>[], 'unread': 0};
  Map<String, Json> messageById = {};
  Json claimsJson = {'items': <Json>[]};
  Map<String, Json> claimById = {};
  Object? failNext;

  Future<T> _call<T>(String name, T Function() ok) async {
    calls.add(name);
    final f = failNext;
    if (f != null) {
      failNext = null;
      throw f;
    }
    if (offline) throw const AppError.offline();
    return ok();
  }

  @override
  Future<List<ScopeWard>> scope() async => [
    for (final w in wards) ScopeWard.fromJson(w),
  ];
  @override
  Future<WardDashboard> dashboard(String wardId) => _call(
    'dashboard:$wardId',
    () => WardDashboard.fromJson(
      dashboardJson(
        wards.firstWhere((w) => w['id'] == wardId),
        election: election,
        open: open,
      ),
    ),
  );
  @override
  Future<Json> wardIssues(
    String wardId, {
    String? status,
    bool overdue = false,
  }) => _call('issues:$wardId:$overdue', () => issuesJson);
  @override
  Future<Json> status(
    String issueId,
    String to,
    String expected, {
    String? note,
  }) => _call('status:$issueId:$to', () => <String, dynamic>{});
  @override
  Future<Json> comment(String issueId, String note) =>
      _call('comment:$issueId', () => <String, dynamic>{});
  @override
  Future<Json> messages() => _call('messages', () => messagesJson);
  @override
  Future<Json> message(String id) =>
      _call('message:$id', () => messageById[id]!);
  @override
  Future<Json> reply(String id, String body) =>
      _call('reply:$id:${body.length}', () => <String, dynamic>{});
  @override
  Future<Json> claims(String? status) =>
      _call('claims:$status', () => claimsJson);
  @override
  Future<Json> claim(String id) => _call('claim:$id', () => claimById[id]!);
  @override
  Future<List<int>> evidence(String claimId, String photoId) async => const [];
  @override
  Future<Json> approve(String id, String method) =>
      _call('approve:$id:$method', () => <String, dynamic>{});
  @override
  Future<Json> reject(String id, String reason) =>
      _call('reject:$id:$reason', () => <String, dynamic>{});
  @override
  Future<Json> revoke(String repId, String reason) =>
      _call('revoke:$repId', () => <String, dynamic>{});
  @override
  Future<List<int>> csv(String wardId, String from, String to) async =>
      '"issue_id"\r\n'.codeUnits;
}
