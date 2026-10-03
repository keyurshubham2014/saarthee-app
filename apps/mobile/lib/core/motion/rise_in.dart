import 'dart:async';

import 'package:flutter/widgets.dart';

import '../theme/motion.dart';

/// Entering content: fade + 14 dp rise with `springIn`, after [delay]
/// (DS §6 `rise`). With [animate] false, or under reduced motion, the child
/// is shown in its end state on the first frame. Inside `StaffMotionScope`
/// it becomes a `short` fade with no rise.
class RiseIn extends StatefulWidget {
  const RiseIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.animate = true,
  });

  final Widget child;
  final Duration delay;
  final bool animate;

  @override
  State<RiseIn> createState() => _RiseInState();
}

class _RiseInState extends State<RiseIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  Timer? _timer;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final scheme = SaartheeMotion.of(context);
    final spec = scheme.springIn;
    if (!widget.animate || spec.isInstant) {
      _c.value = 1;
      return;
    }
    _c.duration = spec.duration;
    final delay = scheme.transforms ? widget.delay : Duration.zero;
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
    final scheme = SaartheeMotion.of(context);
    final curve = scheme.springIn.curve;
    final offset = scheme.riseOffset;
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final t = curve.transform(_c.value);
        final opacity = Curves.easeOut.transform(_c.value).clamp(0.0, 1.0);
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * offset),
            child: child,
          ),
        );
      },
    );
  }
}
