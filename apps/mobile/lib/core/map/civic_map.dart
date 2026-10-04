import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../theme/icons.dart';
import '../theme/motion.dart';
import '../theme/tokens.dart';

export 'package:latlong2/latlong.dart' show LatLng;

/// Tile provider from dart-defines (TASK-05 §3); TASK-07 extends this map.
const String kMapTileUrl = String.fromEnvironment(
  'MAP_TILE_URL',
  defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
);

/// False in widget tests (no network tiles).
final mapTilesEnabledProvider = Provider<bool>((ref) => true);

/// Mini-map with a centre pin (TASK-05 step 2). In [adjusting] mode the
/// citizen pans the map under the fixed pin and [onCenterChanged] reports
/// the new centre; otherwise the map is static. The pin drops in once
/// ([dropPin]) with `springIn` (DS §6), or appears at once with reduced
/// motion.
class CivicMap extends ConsumerWidget {
  const CivicMap({
    super.key,
    required this.center,
    required this.semanticLabel,
    required this.attribution,
    this.adjusting = false,
    this.dropPin = true,
    this.onCenterChanged,
    this.mapController,
    this.height = 180,
  });

  final LatLng center;
  final String semanticLabel;
  final String attribution;
  final bool adjusting;
  final bool dropPin;
  final ValueChanged<LatLng>? onCenterChanged;
  final MapController? mapController;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = SaartheeColors.of(context);
    final tiles = ref.watch(mapTilesEnabledProvider);
    return Semantics(
      label: semanticLabel,
      container: true,
      child: ClipRRect(
        borderRadius: AppRadii.cardRadius,
        child: SizedBox(
          height: height,
          child: RepaintBoundary(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ColoredBox(
                    color: c.surfaceAlt,
                    child: FlutterMap(
                      mapController: mapController,
                      options: MapOptions(
                        initialCenter: center,
                        initialZoom: 17,
                        interactionOptions: InteractionOptions(
                          flags: adjusting
                              ? InteractiveFlag.drag | InteractiveFlag.pinchZoom
                              : InteractiveFlag.none,
                        ),
                        onPositionChanged: (camera, hasGesture) {
                          if (hasGesture) onCenterChanged?.call(camera.center);
                        },
                      ),
                      children: [
                        if (tiles)
                          TileLayer(
                            urlTemplate: kMapTileUrl,
                            userAgentPackageName: 'in.saarthee.app',
                          ),
                      ],
                    ),
                  ),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.s32),
                    child: PinDrop(animate: dropPin, color: c.primary),
                  ),
                ),
                Positioned(
                  right: AppSpacing.s4,
                  bottom: AppSpacing.s4,
                  child: Text(
                    attribution,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: c.textSecondary,
                      backgroundColor: c.surface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The map pin, dropping 24 dp onto the map with `springIn` on first build
/// when [animate] (DS §6 "Location fixed"); no re-drop after moves.
class PinDrop extends StatefulWidget {
  const PinDrop({super.key, required this.color, this.animate = true});

  static const double dropDistance = 24;

  final Color color;
  final bool animate;

  @override
  State<PinDrop> createState() => PinDropState();
}

class PinDropState extends State<PinDrop> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  bool _started = false;

  /// Current vertical offset in dp (−24 → 0), for tests.
  double get offset =>
      -PinDrop.dropDistance * (1 - SaartheeMotion.spring.transform(_c.value));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final spec = SaartheeMotion.of(context).springIn;
    if (!widget.animate || spec.isInstant) {
      _c.value = 1;
      return;
    }
    _c.duration = spec.duration;
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, child) =>
        Transform.translate(offset: Offset(0, offset), child: child),
    child: Icon(SaartheeIcons.location, color: widget.color, size: 36),
  );
}
