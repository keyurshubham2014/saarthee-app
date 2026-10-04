import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/brand.dart';

/// The Saarthee route chevron (the brand mark's "road turn" ending in its
/// dot, without the square), drawn in [color] (`primary`, never `sunrise`).
class ChevronRefreshPainter extends CustomPainter {
  const ChevronRefreshPainter({required this.color, this.progress = 1});

  final Color color;

  /// 0..1: how much of the route is drawn while pulling; the dot appears
  /// once the pull is armed.
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 100;
    final path = Path()
      ..moveTo(
        BrandMarkPainter.routeStart.dx * k,
        BrandMarkPainter.routeStart.dy * k,
      )
      ..lineTo(
        BrandMarkPainter.routeTurnStart.dx * k,
        BrandMarkPainter.routeTurnStart.dy * k,
      )
      ..quadraticBezierTo(
        BrandMarkPainter.routeTurnControl.dx * k,
        BrandMarkPainter.routeTurnControl.dy * k,
        BrandMarkPainter.routeTurnEnd.dx * k,
        BrandMarkPainter.routeTurnEnd.dy * k,
      )
      ..lineTo(
        BrandMarkPainter.routeEnd.dx * k,
        BrandMarkPainter.routeEnd.dy * k,
      );
    final p = progress.clamp(0.0, 1.0);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * math.max(p, 0.05)),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = BrandMarkPainter.routeStroke * k
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    if (p >= 1) {
      canvas.drawCircle(
        BrandMarkPainter.dotCenter * k,
        BrandMarkPainter.dotRadius * k,
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(ChevronRefreshPainter old) =>
      old.color != color || old.progress != progress;
}

/// Branded pull to refresh (DS §6): the route chevron turns with the pull,
/// then spins only while [onRefresh] runs. Reduced motion: a static chevron
/// with "Refreshing…". Wraps any vertical scrollable [child] whose physics
/// allow overscroll at the top (AlwaysScrollableScrollPhysics).
class ChevronRefreshIndicator extends StatefulWidget {
  const ChevronRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
  });

  final Widget child;
  final Future<void> Function() onRefresh;

  /// Pull distance (logical px) that arms a refresh.
  static const double threshold = 72;
  static const double size = 40;

  @override
  State<ChevronRefreshIndicator> createState() =>
      _ChevronRefreshIndicatorState();
}

class _ChevronRefreshIndicatorState extends State<ChevronRefreshIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: SaartheeMotion.shimmerPeriod,
  );
  double _drag = 0;
  bool _refreshing = false;

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0 || _refreshing) return false;
    if (n is OverscrollNotification && n.dragDetails != null) {
      if (n.overscroll < 0 || _drag > 0) {
        setState(() => _drag = math.max(0, _drag - n.overscroll));
      }
    } else if (n is ScrollUpdateNotification && n.dragDetails != null) {
      final m = n.metrics;
      if (m.pixels < m.minScrollExtent) {
        setState(() => _drag = m.minScrollExtent - m.pixels);
      } else if (_drag > 0 && (n.scrollDelta ?? 0) > 0) {
        setState(() => _drag = math.max(0, _drag - n.scrollDelta!));
      }
    } else if (n is ScrollEndNotification) {
      _release();
    }
    return false;
  }

  void _release() {
    if (_drag >= ChevronRefreshIndicator.threshold) {
      _start();
    } else if (_drag != 0) {
      setState(() => _drag = 0);
    }
  }

  Future<void> _start() async {
    final reduced = SaartheeMotion.of(context).isReduced;
    setState(() => _refreshing = true);
    if (!reduced) _spin.repeat();
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) {
        _spin.stop();
        setState(() {
          _refreshing = false;
          _drag = 0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final reduced = SaartheeMotion.of(context).isReduced;
    final progress = _refreshing
        ? 1.0
        : (_drag / ChevronRefreshIndicator.threshold).clamp(0.0, 1.0);
    final visible = _refreshing || _drag > 0;
    final top = _refreshing
        ? AppSpacing.s16
        : math.min(_drag, ChevronRefreshIndicator.threshold) / 2;
    final chevron = SizedBox.square(
      dimension: ChevronRefreshIndicator.size,
      child: CustomPaint(
        key: const Key('chevronRefresh.painter'),
        painter: ChevronRefreshPainter(color: c.primary, progress: progress),
      ),
    );
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: Stack(
        children: [
          widget.child,
          if (visible)
            Positioned(
              top: top,
              left: 0,
              right: 0,
              child: Center(
                child: Semantics(
                  liveRegion: true,
                  label: _refreshing
                      ? AppLocalizations.of(context).discoveryRefreshing
                      : null,
                  child: DecoratedBox(
                    key: const Key('chevronRefresh'),
                    decoration: ShapeDecoration(
                      color: c.surface,
                      shape: AppRadii.pill,
                      shadows: AppElevation.card(c),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.s4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (reduced)
                            chevron
                          else
                            AnimatedBuilder(
                              animation: _spin,
                              builder: (_, child) => Transform.rotate(
                                angle: _refreshing
                                    ? _spin.value * 2 * math.pi
                                    : progress * 1.5 * math.pi,
                                child: child,
                              ),
                              child: chevron,
                            ),
                          if (reduced && _refreshing)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.s8,
                              ),
                              child: Text(
                                AppLocalizations.of(context)
                                    .discoveryRefreshing,
                                key: const Key('chevronRefresh.label'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
