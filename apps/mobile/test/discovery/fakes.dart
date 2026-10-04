import 'dart:async';

import 'package:saarthee/core/api/app_error.dart';
import 'package:saarthee/features/discovery/data/discovery_api.dart';
import 'package:saarthee/features/discovery/data/discovery_models.dart';
import 'package:saarthee/features/discovery/data/map_models.dart';

/// Card JSON as the API sends it (no reporter data).
Map<String, dynamic> cardJson(
  String id, {
  String title = 'Pothole · Paldi',
  String category = 'roads',
  String status = 'reported',
  int meToo = 0,
  bool overdue = false,
  bool pendingReview = false,
  int daysAgo = 3,
}) => {
  'id': id,
  'title': title,
  'categorySlug': category,
  'status': status,
  'displayStatus': status,
  'isOverdue': overdue,
  'wardNameEn': 'Paldi',
  'wardNameGu': 'પાલડી',
  'createdAt': DateTime.now()
      .subtract(Duration(days: daysAgo))
      .toUtc()
      .toIso8601String(),
  'meTooCount': meToo,
  'thumbnailUrl': null,
  'pendingReview': pendingReview,
};

/// `GET /issues/{id}` body.
Map<String, dynamic> detailJson(
  String id, {
  String status = 'reported',
  int meToo = 12,
  bool hasMeToo = false,
  bool isFollowing = false,
  bool isReporter = false,
  bool signedIn = true,
  bool canMeToo = true,
  bool canLinkCcrs = false,
  List<String> after = const [],
  String? mergedIntoId,
  String? rejectionReason,
  bool overdue = false,
}) => {
  'issue': {
    'id': id,
    'title': 'Pothole · Paldi',
    'category': {
      'slug': 'roads',
      'nameEn': 'Roads',
      'nameGu': 'રસ્તા',
      'icon': 'road',
      'colourToken': 'catRoads',
    },
    'status': status,
    'displayStatus': status,
    'isOverdue': overdue,
    'slaDueAt': DateTime.now().add(const Duration(days: 4)).toIso8601String(),
    'ward': {'id': 'w1', 'number': 12, 'nameEn': 'Paldi', 'nameGu': 'પાલડી'},
    'location': {'lat': 23.01, 'lng': 72.56},
    'description': null,
    'photos': {
      'report': <String>[],
      'after': after,
      'verification': <String>[],
    },
    'blurApplied': true,
    'reporterLabel': {'en': 'A resident of Paldi', 'gu': 'પાલડીના રહેવાસી'},
    'meTooCount': meToo,
    'followerCount': 3,
    'createdAt': DateTime.now()
        .subtract(const Duration(days: 3))
        .toIso8601String(),
    'statusChangedAt': DateTime.now().toIso8601String(),
    'mergedIntoId': mergedIntoId,
    'rejectionReason': rejectionReason,
  },
  'viewer': {
    'signedIn': signedIn,
    'isReporter': isReporter,
    'hasMeToo': hasMeToo,
    'isFollowing': isFollowing,
    'canMeToo': canMeToo,
    'canLinkCcrs': canLinkCcrs,
    'canEscalate': false,
  },
};

class FakeDiscoveryApi implements DiscoveryApi {
  FakeDiscoveryApi({
    Map<String, Map<String, dynamic>>? details,
    this.pages = const [],
    this.feedItems = const [],
    this.unknownIsNotFound = false,
  }) : details = details ?? {};

  /// False: an unknown id gets a generic open issue (TASK-06 tests).
  final bool unknownIsNotFound;

  final Map<String, Map<String, dynamic>> details;

  /// Successive `GET /issues` pages (last one repeats).
  List<List<Map<String, dynamic>>> pages;
  List<Map<String, dynamic>> feedItems;
  Object? feedError;
  Object? meTooError;
  Object? detailError;
  MapResult mapResult = MapResult.empty;
  final List<String> calls = [];
  final List<IssueQuery> queries = [];
  Completer<void>? listGate;

  @override
  Future<Map<String, dynamic>> detailRaw(String id, String lang) async {
    calls.add('detail $id');
    if (detailError != null) throw detailError!;
    final d = details[id];
    if (d == null && unknownIsNotFound) {
      throw const AppError(code: 'NOT_FOUND', message: 'x');
    }
    return d ?? detailJson(id);
  }

  @override
  Future<Map<String, dynamic>> feedRaw(String wardId, String lang) async {
    calls.add('feed $wardId');
    if (feedError != null) throw feedError!;
    return {
      'ward': {'id': wardId},
      'sections': {
        'nearbyIssues': {'items': feedItems, 'degraded': false},
      },
    };
  }

  @override
  Future<IssuePage> list(
    IssueQuery q, {
    String? cursor,
    required String lang,
  }) async {
    queries.add(q);
    calls.add('list ${cursor ?? 'first'}');
    if (listGate != null) await listGate!.future;
    if (pages.isEmpty) return const IssuePage([], null);
    final n = cursor == null ? 0 : int.parse(cursor);
    final items = pages[n.clamp(0, pages.length - 1)];
    return IssuePage(
      items.map(IssueCardData.fromJson).toList(),
      n + 1 < pages.length ? '${n + 1}' : null,
    );
  }

  @override
  Future<(int, int?)> meToo(String id, {required bool on}) async {
    calls.add('meToo $id $on');
    if (meTooError != null) throw meTooError!;
    final m = (details[id]?['issue'] as Map?)?['meTooCount'] as int? ?? 0;
    return (on ? m + 1 : m, 4);
  }

  @override
  Future<int> follow(String id, {required bool on}) async {
    calls.add('follow $id $on');
    return on ? 4 : 3;
  }

  @override
  Future<MapResult> map({
    required String bbox,
    required int zoom,
    MapFilters filters = const MapFilters(),
  }) async {
    calls.add('map $zoom');
    return mapResult;
  }
}
