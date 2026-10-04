import 'package:dio/dio.dart';
import 'package:saarthee/core/api/api_client.dart';
import 'package:saarthee/core/api/app_error.dart';
import 'package:saarthee/features/alerts/data/alert_models.dart';
import 'package:saarthee/features/alerts/data/alerts_api.dart';
import 'package:saarthee/features/auth/application/session_controller.dart';
import 'package:saarthee/features/inbox/data/inbox_models.dart';

/// Signed-in (or not) session without Firebase or secure storage.
class FakeSession extends SessionController {
  FakeSession({this.signedIn = true});

  final bool signedIn;

  @override
  SessionState build() =>
      SessionState(token: signedIn ? 'session-jwt' : null, restored: true);
}

Map<String, dynamic> alertJson({
  String id = 'a1',
  String severity = 'info',
  String type = 'water_cut',
  String status = 'published',
  String title = 'Water cut in Paldi',
  DateTime? from,
  DateTime? to,
  String? supersededById,
  String? reason,
}) {
  final f = from ?? DateTime.now().toUtc().subtract(const Duration(hours: 1));
  return {
    'id': id,
    'type': type,
    'severity': severity,
    'titleEn': title,
    'titleGu': 'પાલડીમાં પાણી બંધ',
    'bodyEn': 'No water from 10:00 to 16:00.',
    'bodyGu': '10:00 થી 16:00 પાણી બંધ.',
    'sourceName': 'AMC Water Department',
    'sourceUrl': 'https://ahmedabadcity.gov.in',
    'validFrom': f.toIso8601String(),
    'validTo': (to ?? f.add(const Duration(hours: 6))).toIso8601String(),
    'target': {
      'scope': 'wards',
      'wardIds': ['w12'],
      'wardNumbers': [12],
    },
    'wards': [
      {'id': 'w12', 'number': 12, 'nameEn': 'Paldi', 'nameGu': 'પાલડી'},
    ],
    'status': status,
    'retractionReason': reason,
    'supersededById': supersededById,
  };
}

Map<String, dynamic> inboxJson(
  String id, {
  String kind = 'alert',
  bool read = false,
  DateTime? at,
}) => {
  'id': id,
  'kind': kind,
  'route': kind == 'alert' ? '/alerts/a1' : '/issues/i1',
  'title': 'Title $id',
  'body': 'Body $id',
  'createdAt': (at ?? DateTime.now().toUtc()).toIso8601String(),
  'readAt': read ? DateTime.now().toUtc().toIso8601String() : null,
};

/// Scriptable alerts API (no network).
class FakeAlertsApi extends AlertsApi {
  FakeAlertsApi() : super(ApiClient(Dio()));

  List<Map<String, dynamic>> active = [];
  List<Map<String, dynamic>> past = [];
  Map<String, Map<String, dynamic>> details = {};
  Object? listError;

  /// When set, list calls wait for it (loading state).
  Future<void>? gate;
  AlertSubscriptions subs = const AlertSubscriptions(
    topics: ['ward_12', 'city_all'],
  );
  Object? putError;
  final List<AlertSubscriptions> puts = [];
  List<Map<String, dynamic>> inboxItems = [];
  Object? markError;
  final List<List<String>?> markCalls = [];

  @override
  Future<List<Map<String, dynamic>>> listRaw({
    required List<String> wardIds,
    required bool active,
  }) async {
    if (gate != null) await gate;
    if (listError != null) throw listError!;
    return active ? this.active : past;
  }

  @override
  Future<Map<String, dynamic>> detailRaw(String id) async {
    final d = details[id];
    if (d == null) throw const AppError(code: 'NOT_FOUND', statusCode: 404);
    return d;
  }

  @override
  Future<AlertSubscriptions> mySubscriptions() async => subs;

  @override
  Future<AlertSubscriptions> deviceSubscriptions(String installId) async =>
      subs;

  @override
  Future<AlertSubscriptions> putMySubscriptions(AlertSubscriptions s) async {
    puts.add(s);
    if (putError != null) throw putError!;
    return subs = s;
  }

  @override
  Future<AlertSubscriptions> putDeviceSubscriptions(
    String installId,
    String? homeWardId,
    AlertSubscriptions s,
  ) => putMySubscriptions(s);

  int get _unread => inboxItems.where((i) => i['readAt'] == null).length;

  @override
  Future<InboxPage> inbox({String? cursor}) async =>
      InboxPage.fromJson({'items': inboxItems, 'unreadCount': _unread});

  @override
  Future<int> markRead({List<String>? ids}) async {
    markCalls.add(ids);
    if (markError != null) throw markError!;
    final now = DateTime.now().toUtc().toIso8601String();
    for (final i in inboxItems) {
      if (ids == null || ids.contains(i['id'])) i['readAt'] ??= now;
    }
    return _unread;
  }
}
