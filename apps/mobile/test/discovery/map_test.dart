// W-07-07 map preview sheet + semantics; W-07-09 pin drop (20 animated,
// 30 ms apart), cluster tap camera tween over `long`; W-07-10 reduced;
// client clustering.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/theme/motion.dart';
import 'package:saarthee/core/theme/tokens.dart';
import 'package:saarthee/features/discovery/application/clustering.dart';
import 'package:saarthee/features/discovery/data/map_models.dart';
import 'package:saarthee/features/discovery/presentation/map/map_markers.dart';
import 'package:saarthee/features/discovery/presentation/map/map_tab_screen.dart';

import 'fakes.dart';
import 'harness.dart';

List<MapPoint> grid(int n) => [
  for (var i = 0; i < n; i++)
    MapPoint(
      id: 'p$i',
      lat: kDefaultMapCenter.latitude - 0.012 + (i ~/ 5) * 0.006,
      lng: kDefaultMapCenter.longitude - 0.012 + (i % 5) * 0.006,
      categorySlug: 'roads',
      status: IssueStatus.reported,
      isOverdue: false,
    ),
];

double pinOpacity(WidgetTester t, String id) => t
    .widget<Opacity>(
      find
          .descendant(
            of: find.byKey(Key('map.pin.$id')),
            matching: find.byType(Opacity),
          )
          .first,
    )
    .opacity;

Future<FakeDiscoveryApi> pumpMap(
  WidgetTester t,
  MapResult result, {
  bool? reduced,
}) async {
  final api = FakeDiscoveryApi()..mapResult = result;
  await pumpDiscovery(
    t,
    home: const MapTabScreen(),
    api: api,
    reduced: reduced,
  );
  await t.pump(); // post-frame first load
  await t.pump(); // result arrives
  return api;
}

void main() {
  test('client clustering: far points stay pins, near points merge', () {
    final r = clusterPoints(grid(25), kDefaultMapZoom);
    expect(r.pins, hasLength(25));
    expect(r.clusters, isEmpty);
    final near = [
      for (var i = 0; i < 4; i++)
        MapPoint(
          id: 'n$i',
          lat: 23.0 + i * 0.00001,
          lng: 72.5,
          categorySlug: i == 0 ? 'water' : 'garbage',
          status: IssueStatus.reported,
          isOverdue: i == 3,
        ),
    ];
    final c = clusterPoints(near, 14);
    expect(c.pins, isEmpty);
    expect(c.clusters.single.count, 4);
    expect(c.clusters.single.topCategory, 'garbage');
    expect(c.clusters.single.hasOverdue, isTrue);
  });

  test('pin delays: 30 ms apart, pins past 20 land with the 20th', () {
    const step = SaartheeMotion.mapPinStagger;
    expect(PinDropIn.delayFor(0, step), Duration.zero);
    expect(PinDropIn.delayFor(5, step), step * 5);
    expect(PinDropIn.delayFor(19, step), step * 19);
    expect(PinDropIn.delayFor(24, step), PinDropIn.delayFor(19, step));
  });

  testWidgets('W-07-07 pins and clusters have labels; pin tap → preview', (
    t,
  ) async {
    final result = MapResult(
      points: grid(1),
      clusters: const [
        MapCluster(lat: 23.02, lng: 72.57, count: 12, topCategory: 'roads'),
      ],
    );
    final api = await pumpMap(t, result);
    api.details['p0'] = detailJson('p0');
    await settle(t);
    expect(find.bySemanticsLabel('Roads, Reported'), findsOneWidget);
    expect(find.bySemanticsLabel('12 issues here, zoom in'), findsOneWidget);
    expect(find.byKey(const Key('map.showList')), findsOneWidget);
    await t.tap(find.byKey(const Key('map.pin.p0')));
    await settle(t);
    expect(find.byKey(const Key('map.preview')), findsOneWidget);
    await t.tap(find.byKey(const Key('map.preview.details')));
    await settle(t);
    expect(find.byKey(const Key('detail.title')), findsOneWidget);
  });

  testWidgets('W-07-09 25 pins: first 20 drop 30 ms apart, 21–25 with the '
      '20th; no re-drop', (t) async {
    await pumpMap(t, MapResult(points: grid(25), clusters: const []));
    await t.pump(SaartheeMotion.mapPinStagger * 2);
    expect(pinOpacity(t, 'p0'), greaterThan(0));
    expect(pinOpacity(t, 'p10'), 0);
    expect(pinOpacity(t, 'p22'), 0);
    // Just after pin 20 (index 19) starts, 21–25 start too.
    await t.pump(SaartheeMotion.mapPinStagger * 18);
    await t.pump(SaartheeMotion.springIn.duration ~/ 2);
    expect(pinOpacity(t, 'p19'), greaterThan(0));
    expect(pinOpacity(t, 'p24'), closeTo(pinOpacity(t, 'p19'), 0.001));
    await settle(t);
    for (final id in ['p0', 'p19', 'p24']) {
      expect(pinOpacity(t, id), 1);
    }
  });

  testWidgets('W-07-09 cluster tap zooms the camera over `long`, then '
      'reloads', (t) async {
    final api = await pumpMap(
      t,
      MapResult(
        points: const [],
        clusters: [
          MapCluster(
            lat: kDefaultMapCenter.latitude,
            lng: kDefaultMapCenter.longitude,
            count: 9,
            topCategory: 'roads',
          ),
        ],
      ),
    );
    await settle(t);
    final before = api.calls.length;
    await t.tap(find.bySemanticsLabel('9 issues here, zoom in'));
    await t.pump();
    await t.pump(SaartheeMotion.long.duration ~/ 2);
    expect(api.calls.length, before);
    await settle(t, 4);
    expect(api.calls.last, 'map ${(kDefaultMapZoom + 2).round()}');
  });

  testWidgets('W-07-10 reduced motion: pins appear at once', (t) async {
    await pumpMap(
      t,
      MapResult(points: grid(25), clusters: const []),
      reduced: true,
    );
    await t.pump();
    expect(pinOpacity(t, 'p0'), 1);
    expect(pinOpacity(t, 'p24'), 1);
  });
}
