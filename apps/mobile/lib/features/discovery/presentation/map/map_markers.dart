import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/motion.dart';
import '../../../../core/theme/tokens.dart';

/// Teardrop pin (DS §5 map): category colour, white glyph, status ring.
class TeardropPin extends StatelessWidget {
  const TeardropPin({
    super.key,
    required this.categorySlug,
    required this.status,
    required this.semanticLabel,
  });

  final String categorySlug;
  final IssueStatus status;
  final String semanticLabel;

  static const double width = 36;
  static const double height = 46;

  @override
  Widget build(BuildContext context) {
    final cat = CategoryStyle.of(categorySlug);
    final ring = IssueStatusStyle.styles[status]!.solid;
    final c = SaartheeColors.of(context);
    return Semantics(
      label: semanticLabel,
      button: true,
      excludeSemantics: true,
      child: SizedBox(
        width: width,
        height: height,
        child: CustomPaint(
          painter: _TeardropPainter(
            fill: cat.color,
            ring: ring,
            edge: c.surface,
          ),
          child: Padding(
            padding: const EdgeInsets.only(top: 7, bottom: 17),
            child: Center(
              child: Icon(cat.icon, size: 18, color: NeemFixed.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _TeardropPainter extends CustomPainter {
  const _TeardropPainter({
    required this.fill,
    required this.ring,
    required this.edge,
  });

  final Color fill, ring, edge;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2 - 2;
    final center = Offset(size.width / 2, r + 2);
    final tip = Offset(size.width / 2, size.height - 1);
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..quadraticBezierTo(
        center.dx - r * 0.9,
        center.dy + r * 0.9,
        center.dx - r,
        center.dy,
      )
      ..arcToPoint(Offset(center.dx + r, center.dy), radius: Radius.circular(r))
      ..quadraticBezierTo(
        center.dx + r * 0.9,
        center.dy + r * 0.9,
        tip.dx,
        tip.dy,
      )
      ..close();
    canvas.drawPath(path, Paint()..color = fill);
    // Status ring around the head (white gap, then the status colour).
    canvas.drawCircle(
      center,
      r - 1.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = ring,
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = edge,
    );
  }

  @override
  bool shouldRepaint(_TeardropPainter old) =>
      old.fill != fill || old.ring != ring || old.edge != edge;
}

/// Slate cluster bubble with its count (DS §5 map).
class ClusterBubble extends StatelessWidget {
  const ClusterBubble({
    super.key,
    required this.count,
    required this.semanticLabel,
    this.hasOverdue = false,
  });

  final int count;
  final bool hasOverdue;
  final String semanticLabel;

  static double sizeFor(int count) => count < 10
      ? 40
      : count < 100
      ? 48
      : 56;

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final d = sizeFor(count);
    return Semantics(
      label: semanticLabel,
      button: true,
      excludeSemantics: true,
      child: Container(
        width: d,
        height: d,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // DS slate (#4B5768, the neutral "reported" solid).
          color: IssueStatusStyle.styles[IssueStatus.reported]!.solid,
          border: Border.all(color: hasOverdue ? c.error : c.surface, width: 3),
        ),
        child: Text(
          '$count',
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(color: NeemFixed.white),
        ),
      ),
    );
  }
}

/// Pin drop (DS §6 map): translate-Y from −12 dp + fade with `springIn`
/// after `index × mapPinStagger`; pins past [SaartheeMotion.mapPinMaxAnimated]
/// land with the last animated one. [animate] false (already shown, reduced
/// motion) → end state on the first frame.
class PinDropIn extends StatefulWidget {
  const PinDropIn({
    super.key,
    required this.child,
    required this.index,
    this.animate = true,
  });

  final Widget child;
  final int index;
  final bool animate;

  static const double dropFrom = -12;

  /// Delay of pin [index] (0-based) for a stagger of [step].
  static Duration delayFor(int index, Duration step) {
    final capped = index < SaartheeMotion.mapPinMaxAnimated
        ? index
        : SaartheeMotion.mapPinMaxAnimated - 1;
    return step * capped;
  }

  @override
  State<PinDropIn> createState() => _PinDropInState();
}

class _PinDropInState extends State<PinDropIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  Timer? _delay;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final m = SaartheeMotion.of(context);
    if (!widget.animate || !m.transforms) {
      _c.value = 1;
      return;
    }
    _c.duration = m.springIn.duration;
    final wait = PinDropIn.delayFor(widget.index, m.mapPinStagger);
    if (wait == Duration.zero) {
      _c.forward();
    } else {
      _delay = Timer(wait, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _c, curve: SaartheeMotion.spring);
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => Opacity(
        opacity: _c.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, PinDropIn.dropFrom * (1 - curve.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}
