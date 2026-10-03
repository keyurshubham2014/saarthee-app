import 'dart:async';

import 'package:flutter/widgets.dart';

import '../theme/motion.dart';

/// Tile pop (DS §6 report step 1): scale 0.88 → 1 with `springIn`, item
/// [index] starting `index × tileStagger` (35 ms) after the first. Reduced
/// motion or [animate] false → end state on the first frame.
class PopIn extends StatefulWidget {
  const PopIn({
    super.key,
    required this.child,
    this.index = 0,
    this.animate = true,
  });

  final Widget child;
  final int index;
  final bool animate;

  @override
  State<PopIn> createState() => _PopInState();
}

class _PopInState extends State<PopIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  Timer? _timer;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final scheme = SaartheeMotion.of(context);
    if (!widget.animate || !scheme.transforms) {
      _c.value = 1;
      return;
    }
    _c.duration = scheme.springIn.duration;
    final delay = scheme.tileStagger * widget.index;
    if (delay == Duration.zero) {
      _c.forward();
    } else {
      _timer = Timer(delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final t = SaartheeMotion.spring.transform(_c.value);
        final from = SaartheeMotion.popScaleFrom;
        return Opacity(
          opacity: _c.value.clamp(0.0, 1.0),
          child: Transform.scale(scale: from + (1 - from) * t, child: child),
        );
      },
    );
  }
}
