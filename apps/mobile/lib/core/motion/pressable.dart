import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/motion.dart';
import 'haptics.dart';

/// Press feedback (DS §6 "Buttons and cards"): scales to 0.97 on press down
/// over `instant`, back on release or cancel. Uses a raw [Listener], so it
/// never takes part in the gesture arena and never blocks the child's tap.
/// With [haptic] a light haptic fires when a press ends as a tap.
/// No scale under reduced motion or inside `StaffMotionScope`.
class Pressable extends ConsumerStatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.enabled = true,
    this.haptic = false,
  });

  final Widget child;
  final bool enabled;
  final bool haptic;

  @override
  ConsumerState<Pressable> createState() => _PressableState();
}

class _PressableState extends ConsumerState<Pressable> {
  bool _down = false;
  Offset? _start;
  bool _moved = false;

  void _set(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = SaartheeMotion.of(context);
    final spec = scheme.instant;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: widget.enabled
          ? (e) {
              _start = e.position;
              _moved = false;
              _set(true);
            }
          : null,
      onPointerMove: (e) {
        if (_start != null && (e.position - _start!).distance > kTouchSlop) {
          _moved = true;
          _set(false);
        }
      },
      onPointerUp: (_) {
        if (widget.enabled && widget.haptic && _down && !_moved) {
          ref.read(saartheeHapticsProvider).light();
        }
        _set(false);
      },
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? scheme.pressScale : 1,
        duration: spec.duration,
        curve: spec.curve,
        child: widget.child,
      ),
    );
  }
}
