import '../../../core/theme/tokens.dart';
import 'discovery_models.dart';

/// A server point (`mode: points`) or a pin after client clustering.
class MapPoint {
  const MapPoint({
    required this.id,
    required this.lat,
    required this.lng,
    required this.categorySlug,
    required this.status,
    required this.isOverdue,
  });

  factory MapPoint.fromJson(Map<String, dynamic> j) => MapPoint(
    id: j['id'] as String,
    lat: (j['lat'] as num).toDouble(),
    lng: (j['lng'] as num).toDouble(),
    categorySlug: j['categorySlug'] as String? ?? 'other',
    status: parseIssueStatus(j['status'] as String?),
    isOverdue: j['isOverdue'] == true,
  );

  final String id, categorySlug;
  final double lat, lng;
  final IssueStatus status;
  final bool isOverdue;
}

/// A cluster bubble (server grid cell or client cluster).
class MapCluster {
  const MapCluster({
    required this.lat,
    required this.lng,
    required this.count,
    required this.topCategory,
    this.hasOverdue = false,
  });

  factory MapCluster.fromJson(Map<String, dynamic> j) => MapCluster(
    lat: (j['lat'] as num).toDouble(),
    lng: (j['lng'] as num).toDouble(),
    count: (j['count'] as num).toInt(),
    topCategory: j['topCategory'] as String? ?? 'other',
    hasOverdue: j['hasOverdue'] == true,
  );

  final double lat, lng;
  final int count;
  final String topCategory;
  final bool hasOverdue;

  /// Stable identity for "already shown" pin-drop bookkeeping.
  String get key => 'c:${lat.toStringAsFixed(5)},${lng.toStringAsFixed(5)}';
}

/// `GET /map/issues` result.
class MapResult {
  const MapResult({
    required this.points,
    required this.clusters,
    this.truncated = false,
  });

  factory MapResult.fromJson(Map<String, dynamic> j) {
    final items = (j['items'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    if (j['mode'] == 'points') {
      return MapResult(
        points: items.map(MapPoint.fromJson).toList(),
        clusters: const [],
        truncated: j['truncated'] == true,
      );
    }
    return MapResult(
      points: const [],
      clusters: items.map(MapCluster.fromJson).toList(),
      truncated: j['truncated'] == true,
    );
  }

  static const empty = MapResult(points: [], clusters: []);

  final List<MapPoint> points;
  final List<MapCluster> clusters;
  final bool truncated;

  bool get isEmpty => points.isEmpty && clusters.isEmpty;
}

/// Map filters (chips): categories, status group, mine.
class MapFilters {
  const MapFilters({
    this.categories = const {},
    this.statuses = const {},
    this.mine = false,
  });

  final Set<String> categories;
  final Set<String> statuses;
  final bool mine;

  MapFilters copyWith({
    Set<String>? categories,
    Set<String>? statuses,
    bool? mine,
  }) => MapFilters(
    categories: categories ?? this.categories,
    statuses: statuses ?? this.statuses,
    mine: mine ?? this.mine,
  );
}
