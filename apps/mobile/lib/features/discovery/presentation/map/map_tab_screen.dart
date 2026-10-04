import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/app_error.dart';
import '../../../../core/config/timings.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/map/civic_map.dart';
import '../../../../core/theme/icons.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/wards/ward_providers.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/application/session_controller.dart';
import '../../application/clustering.dart';
import '../../data/discovery_api.dart';
import '../../data/map_models.dart';
import '../issue_list_screens.dart';
import 'map_markers.dart';
import 'map_preview_sheet.dart';

/// Paldi, used when location is unavailable (wards carry no centroid here).
const LatLng kDefaultMapCenter = LatLng(23.0105, 72.5605);
const double kDefaultMapZoom = 14;

/// Map tab (TASK-07, replaces P-04): muted `CivicMap`, teardrop pins and
/// cluster bubbles (server grid below zoom 15, client clustering above),
/// filter chips (Category, Status, Mine), "My location", "Show as list",
/// pin tap → preview sheet, cluster tap → camera zoom over `long`.
class MapTabScreen extends ConsumerStatefulWidget {
  const MapTabScreen({super.key});

  @override
  ConsumerState<MapTabScreen> createState() => _MapTabScreenState();
}

class _MapTabScreenState extends ConsumerState<MapTabScreen>
    with SingleTickerProviderStateMixin {
  final _map = MapController();
  late final AnimationController _cam = AnimationController(vsync: this);
  Timer? _debounce;
  MapFilters _filters = const MapFilters();
  MapResult _result = MapResult.empty;
  bool _loading = false, _offline = false, _ready = false;
  int _gen = 0;

  /// Pins/clusters already dropped in; panning never re-animates them.
  final Set<String> _shown = {};

  @override
  void dispose() {
    _debounce?.cancel();
    _cam.dispose();
    super.dispose();
  }

  String _bbox(MapCamera cam) {
    final b = cam.visibleBounds;
    // The API caps a bbox at 0.5° per axis.
    double clampSpan(double lo, double hi) => hi - lo > 0.5 ? lo + 0.5 : hi;
    final w = b.west, s = b.south;
    final e = clampSpan(w, b.east), n = clampSpan(s, b.north);
    return [w, s, e, n].map((v) => v.toStringAsFixed(5)).join(',');
  }

  void _scheduleLoad() {
    _debounce?.cancel();
    _debounce = Timer(AppTimings.mapIdleDebounce, _load);
  }

  Future<void> _load() async {
    if (!mounted) return;
    final cam = _map.camera;
    final gen = ++_gen;
    setState(() => _loading = true);
    try {
      final r = await ref
          .read(discoveryApiProvider)
          .map(bbox: _bbox(cam), zoom: cam.zoom.round(), filters: _filters);
      if (!mounted || gen != _gen) return;
      setState(() {
        _result = r;
        _loading = false;
        _offline = false;
      });
    } catch (e) {
      if (!mounted || gen != _gen) return;
      final err = AppError.from(e);
      setState(() {
        _loading = false;
        _offline = err.isOffline;
      });
      if (!err.isOffline) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).discoveryMapLoadError),
          ),
        );
      }
    }
  }

  /// Camera tween to [target] over `long`; reduced motion jumps.
  void _animateTo(LatLng target, double zoom) {
    final spec = SaartheeMotion.of(context).long;
    final from = _map.camera;
    if (spec.duration == Duration.zero ||
        !SaartheeMotion.of(context).transforms) {
      _map.move(target, zoom);
      _scheduleLoad();
      return;
    }
    _cam.duration = spec.duration;
    final curve = CurvedAnimation(parent: _cam, curve: spec.curve);
    void tick() {
      final t = curve.value;
      _map.move(
        LatLng(
          from.center.latitude + (target.latitude - from.center.latitude) * t,
          from.center.longitude +
              (target.longitude - from.center.longitude) * t,
        ),
        from.zoom + (zoom - from.zoom) * t,
      );
    }

    _cam.addListener(tick);
    _cam.forward(from: 0).whenComplete(() {
      _cam.removeListener(tick);
      _scheduleLoad();
    });
  }

  Future<void> _myLocation() async {
    try {
      final p = await ref.read(deviceLocatorProvider).currentPosition();
      if (mounted) _animateTo(LatLng(p.lat, p.lng), 16);
    } catch (_) {
      // Location denied: the map stays where it is (home area).
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final signedIn = ref.watch(sessionProvider.select((s) => s.signedIn));
    final zoom = _ready ? _map.camera.zoom : kDefaultMapZoom;
    final clustered = clusterPoints(_result.points, zoom);
    final clusters = [..._result.clusters, ...clustered.clusters];
    final pins = clustered.pins;
    var animIndex = 0;
    final markers = <Marker>[
      for (final cl in clusters)
        Marker(
          key: ValueKey(cl.key),
          point: LatLng(cl.lat, cl.lng),
          width: ClusterBubble.sizeFor(cl.count),
          height: ClusterBubble.sizeFor(cl.count),
          child: GestureDetector(
            onTap: () => _animateTo(
              LatLng(cl.lat, cl.lng),
              (_map.camera.zoom + 2).clamp(0, 18).toDouble(),
            ),
            child: PinDropIn(
              index: _shown.contains(cl.key) ? 0 : animIndex++,
              animate: _shown.add(cl.key),
              child: ClusterBubble(
                count: cl.count,
                hasOverdue: cl.hasOverdue,
                semanticLabel: l10n.discoveryMapClusterLabel(cl.count),
              ),
            ),
          ),
        ),
      for (final p in pins)
        Marker(
          key: ValueKey('p:${p.id}'),
          point: LatLng(p.lat, p.lng),
          width: TeardropPin.width,
          height: TeardropPin.height,
          alignment: Alignment.topCenter,
          child: GestureDetector(
            key: Key('map.pin.${p.id}'),
            onTap: () => showMapPreview(context, p.id),
            child: PinDropIn(
              index: _shown.contains('p:${p.id}') ? 0 : animIndex++,
              animate: _shown.add('p:${p.id}'),
              child: TeardropPin(
                categorySlug: p.categorySlug,
                status: p.status,
                semanticLabel: l10n.discoveryMapPinLabel(
                  categoryLabel(l10n, p.categorySlug),
                  issueStatusLabel(l10n, p.status),
                ),
              ),
            ),
          ),
        ),
    ];
    return Scaffold(
      appBar: SaartheeAppBar(title: l10n.navMap, showBack: false),
      body: Column(
        children: [
          _Filters(
            filters: _filters,
            signedIn: signedIn,
            onChanged: (f) {
              setState(() => _filters = f);
              _scheduleLoad();
            },
          ),
          if (_loading) const LinearProgressIndicator(key: Key('map.loading')),
          if (_offline)
            NoticeBanner(
              kind: NoticeKind.offline,
              message: l10n.discoveryMapOffline,
            ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: CivicMap(
                    key: const Key('map.civic'),
                    center: kDefaultMapCenter,
                    initialZoom: kDefaultMapZoom,
                    semanticLabel: l10n.discoveryMapLabel,
                    attribution: l10n.reportFlowMapAttribution,
                    mapController: _map,
                    height: null,
                    interactive: true,
                    muted: true,
                    showCenterPin: false,
                    layers: [MarkerLayer(markers: markers)],
                    onMapEvent: (e) {
                      if (e is MapEventMoveEnd ||
                          e is MapEventFlingAnimationEnd ||
                          e is MapEventDoubleTapZoomEnd ||
                          e is MapEventScrollWheelZoom) {
                        _scheduleLoad();
                      }
                    },
                  ),
                ),
                // First load once the map has a camera.
                _MapReady(
                  onReady: () {
                    _ready = true;
                    _load();
                  },
                ),
                if (!_loading && _result.isEmpty && _ready && !_offline)
                  Positioned(
                    top: AppSpacing.s12,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Chip(
                        key: const Key('map.empty'),
                        label: Text(l10n.discoveryMapEmpty),
                      ),
                    ),
                  ),
                Positioned(
                  right: AppSpacing.s12,
                  bottom: AppSpacing.s32,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      FloatingActionButton.small(
                        key: const Key('map.myLocation'),
                        heroTag: null,
                        tooltip: l10n.discoveryMapMyLocation,
                        onPressed: _myLocation,
                        child: const Icon(SaartheeIcons.myLocation),
                      ),
                      const SizedBox(height: AppSpacing.s12),
                      FloatingActionButton.extended(
                        key: const Key('map.showList'),
                        heroTag: null,
                        onPressed: () => context.push(
                          Uri(
                            path: '/issues',
                            queryParameters: {'bbox': _bbox(_map.camera)},
                          ).toString(),
                        ),
                        icon: const Icon(SaartheeIcons.listAlt),
                        label: Text(l10n.discoveryMapShowList),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Calls [onReady] once after the first frame (the MapController is attached).
class _MapReady extends StatefulWidget {
  const _MapReady({required this.onReady});

  final VoidCallback onReady;

  @override
  State<_MapReady> createState() => _MapReadyState();
}

class _MapReadyState extends State<_MapReady> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onReady();
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.filters,
    required this.signedIn,
    required this.onChanged,
  });

  final MapFilters filters;
  final bool signedIn;
  final ValueChanged<MapFilters> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget status(String g, String label) => Padding(
      padding: const EdgeInsetsDirectional.only(start: AppSpacing.s8),
      child: AppFilterChip(
        key: Key('map.filter.$g'),
        label: label,
        selected: filters.statuses.contains(g),
        onSelected: (on) => onChanged(
          filters.copyWith(
            statuses: on
                ? {...filters.statuses, g}
                : ({...filters.statuses}..remove(g)),
          ),
        ),
      ),
    );
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
        children: [
          AppFilterChip(
            key: const Key('map.filter.category'),
            label: filters.categories.isEmpty
                ? l10n.discoveryFilterCategory
                : '${l10n.discoveryFilterCategory} (${filters.categories.length})',
            icon: SaartheeIcons.category,
            selected: filters.categories.isNotEmpty,
            onSelected: (_) async {
              final picked = await pickCategories(context, filters.categories);
              if (picked != null) {
                onChanged(filters.copyWith(categories: picked));
              }
            },
          ),
          status('open', l10n.discoveryStatusOpen),
          status('overdue', l10n.discoveryStatusOverdue),
          status('fixed', l10n.discoveryStatusFixed),
          if (signedIn)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: AppSpacing.s8),
              child: AppFilterChip(
                key: const Key('map.filter.mine'),
                label: l10n.discoveryMapMine,
                selected: filters.mine,
                onSelected: (on) => onChanged(filters.copyWith(mine: on)),
              ),
            ),
        ],
      ),
    );
  }
}
