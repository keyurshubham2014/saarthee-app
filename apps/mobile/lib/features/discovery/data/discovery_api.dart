import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import 'discovery_models.dart';
import 'map_models.dart';

/// Status chip groups (§5.4) → server `status` csv values.
const Map<String, List<String>> statusGroups = {
  'open': ['reported', 'sent', 'acknowledged', 'in_progress', 'reopened'],
  'overdue': ['overdue'],
  'fixed': ['marked_fixed'],
  'verified': ['verified'],
};

List<String> statusValues(Set<String> groups) => [
  for (final g in groups) ...?statusGroups[g],
];

/// `GET /issues` query (filters + sort); the cursor is passed separately.
class IssueQuery {
  const IssueQuery({
    this.wardId,
    this.categories = const {},
    this.statuses = const {},
    this.sort = 'newest',
    this.mine = false,
    this.following = false,
    this.bbox,
  });

  final String? wardId;
  final Set<String> categories;

  /// Status groups: open, overdue, fixed, verified.
  final Set<String> statuses;
  final String sort;
  final bool mine, following;

  /// minLng,minLat,maxLng,maxLat.
  final String? bbox;

  bool get hasFilters => categories.isNotEmpty || statuses.isNotEmpty;

  IssueQuery copyWith({
    Set<String>? categories,
    Set<String>? statuses,
    String? sort,
  }) => IssueQuery(
    wardId: wardId,
    categories: categories ?? this.categories,
    statuses: statuses ?? this.statuses,
    sort: sort ?? this.sort,
    mine: mine,
    following: following,
    bbox: bbox,
  );

  Map<String, dynamic> toQuery(String lang) => {
    'ward': ?wardId,
    if (categories.isNotEmpty) 'category': categories.join(','),
    if (statuses.isNotEmpty) 'status': statusValues(statuses).join(','),
    'sort': sort,
    if (mine) 'mine': 'true',
    if (following) 'following': 'true',
    'bbox': ?bbox,
    'lang': lang,
  };

  @override
  bool operator ==(Object other) =>
      other is IssueQuery &&
      other.wardId == wardId &&
      other.sort == sort &&
      other.mine == mine &&
      other.following == following &&
      other.bbox == bbox &&
      _setEq(other.categories, categories) &&
      _setEq(other.statuses, statuses);

  @override
  int get hashCode => Object.hash(
    wardId,
    sort,
    mine,
    following,
    bbox,
    Object.hashAllUnordered(categories),
    Object.hashAllUnordered(statuses),
  );
}

bool _setEq(Set<String> a, Set<String> b) =>
    a.length == b.length && a.containsAll(b);

/// Discovery reads and social actions (TASK-07 §5.3). Tests fake it.
abstract class DiscoveryApi {
  Future<IssuePage> list(IssueQuery q, {String? cursor, required String lang});
  Future<Map<String, dynamic>> feedRaw(String wardId, String lang);
  Future<Map<String, dynamic>> detailRaw(String id, String lang);

  /// Returns `(meTooCount, followerCount?)`.
  Future<(int, int?)> meToo(String id, {required bool on});

  /// Returns the follower count.
  Future<int> follow(String id, {required bool on});
  Future<MapResult> map({
    required String bbox,
    required int zoom,
    MapFilters filters = const MapFilters(),
  });
}

class HttpDiscoveryApi implements DiscoveryApi {
  HttpDiscoveryApi(this._api);

  final ApiClient _api;

  @override
  Future<IssuePage> list(
    IssueQuery q, {
    String? cursor,
    required String lang,
  }) async => IssuePage.fromJson(
    await _api.getJson(
      '/issues',
      query: {...q.toQuery(lang), 'cursor': ?cursor},
    ),
  );

  @override
  Future<Map<String, dynamic>> feedRaw(String wardId, String lang) =>
      _api.getJson('/feed', query: {'ward': wardId, 'lang': lang});

  @override
  Future<Map<String, dynamic>> detailRaw(String id, String lang) =>
      _api.getJson('/issues/$id', query: {'lang': lang});

  @override
  Future<(int, int?)> meToo(String id, {required bool on}) async {
    final r = on
        ? await _api.postJson('/issues/$id/me-too')
        : await _api.deleteJson('/issues/$id/me-too');
    return (
      (r['meTooCount'] as num).toInt(),
      (r['followerCount'] as num?)?.toInt(),
    );
  }

  @override
  Future<int> follow(String id, {required bool on}) async {
    final r = on
        ? await _api.postJson('/issues/$id/follow')
        : await _api.deleteJson('/issues/$id/follow');
    return (r['followerCount'] as num).toInt();
  }

  @override
  Future<MapResult> map({
    required String bbox,
    required int zoom,
    MapFilters filters = const MapFilters(),
  }) async => MapResult.fromJson(
    await _api.getJson(
      '/map/issues',
      query: {
        'bbox': bbox,
        'zoom': zoom,
        if (filters.categories.isNotEmpty)
          'category': filters.categories.join(','),
        if (filters.statuses.isNotEmpty)
          'status': statusValues(filters.statuses).join(','),
        if (filters.mine) 'mine': 'true',
      },
    ),
  );
}

final discoveryApiProvider = Provider<DiscoveryApi>(
  (ref) => HttpDiscoveryApi(ref.watch(apiClientProvider)),
);
