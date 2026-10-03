import 'dart:async';
import 'dart:ui' show PathMetric;

import 'package:flutter/widgets.dart';

import '../theme/motion.dart';

/// Success check drawn as a stroke (DS §6 `drawCheck`): starts 150 ms after
/// it appears and completes 450 ms later. `CustomPainter`, no Lottie.
/// Reduced motion → fully drawn on the first frame. [progress] pins the
/// drawing (goldens).
class MotionCheck extends StatefulWidget {
  const MotionCheck({
    super.key,
    required this.color,
    required this.semanticLabel,
    this.size = 24,
    this.strokeWidth = 2.5,
    this.progress,
  });

  final Color color;
  final String semanticLabel;
  final double size;
  final double strokeWidth;
  final double? progress;

  @override
  State<MotionCheck> createState() => _MotionCheckState();
}

class _MotionCheckState extends State<MotionCheck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  Timer? _timer;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started || widget.progress != null) return;
    _started = true;
    final scheme = SaartheeMotion.of(context);
    final spec = scheme.drawCheck;
    if (spec.isInstant) {
      _c.value = 1;
      return;
    }
    _c.duration = spec.duration;
    _timer = Timer(scheme.drawCheckDelay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  /// Current drawing progress (0–1), for tests.
  double get progress => widget.progress ?? _c.value;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticLabel,
      image: true,
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(
            painter: CheckPainter(
              progress: SaartheeMotion.drawCheck.curve.transform(
                (widget.progress ?? _c.value).clamp(0.0, 1.0),
              ),
              color: widget.color,
              strokeWidth: widget.strokeWidth,
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints the first [progress] of a check-mark path.
class CheckPainter extends CustomPainter {
  const CheckPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.2, h * 0.53)
      ..lineTo(w * 0.42, h * 0.74)
      ..lineTo(w * 0.8, h * 0.3);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final metrics = path.computeMetrics().toList();
    final total = metrics.fold<double>(0, (s, PathMetric m) => s + m.length);
    var remaining = total * progress;
    for (final m in metrics) {
      if (remaining <= 0) break;
      final len = remaining < m.length ? remaining : m.length;
      canvas.drawPath(m.extractPath(0, len), paint);
      remaining -= len;
    }
  }

  @override
  bool shouldRepaint(CheckPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.strokeWidth != strokeWidth;
}
