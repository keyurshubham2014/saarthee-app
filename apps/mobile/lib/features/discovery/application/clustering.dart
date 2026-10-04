import 'dart:math' as math;

import '../data/map_models.dart';

/// Client clustering of server points (REQ-N-008, together with the server
/// grid below zoom 15): points whose Web-Mercator pixels share a
/// [cellPx]-square cell at [zoom] become one bubble; single points stay pins.
class ClusterResult {
  const ClusterResult(this.pins, this.clusters);

  final List<MapPoint> pins;
  final List<MapCluster> clusters;
}

const double defaultCellPx = 64;

ClusterResult clusterPoints(
  List<MapPoint> points,
  double zoom, {
  double cellPx = defaultCellPx,
}) {
  final scale = 256 * math.pow(2, zoom).toDouble();
  final cells = <(int, int), List<MapPoint>>{};
  for (final p in points) {
    final x = (p.lng + 180) / 360 * scale;
    final s = math.sin(p.lat * math.pi / 180).clamp(-0.9999, 0.9999);
    final y = (0.5 - math.log((1 + s) / (1 - s)) / (4 * math.pi)) * scale;
    cells
        .putIfAbsent((x ~/ cellPx, y ~/ cellPx), () => <MapPoint>[])
        .add(p);
  }
  final pins = <MapPoint>[];
  final clusters = <MapCluster>[];
  for (final group in cells.values) {
    if (group.length == 1) {
      pins.add(group.first);
      continue;
    }
    final counts = <String, int>{};
    for (final p in group) {
      counts[p.categorySlug] = (counts[p.categorySlug] ?? 0) + 1;
    }
    final top = counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
    clusters.add(
      MapCluster(
        lat: group.fold(0.0, (s, p) => s + p.lat) / group.length,
        lng: group.fold(0.0, (s, p) => s + p.lng) / group.length,
        count: group.length,
        topCategory: top,
        hasOverdue: group.any((p) => p.isOverdue),
      ),
    );
  }
  return ClusterResult(pins, clusters);
}
