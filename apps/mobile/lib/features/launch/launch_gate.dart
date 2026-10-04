import 'package:flutter/material.dart';

import '../../core/motion/motion_widgets.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';

/// Launch motion (DS §6 "App launch"): over the native `primary` splash the
/// first Flutter frame shows the mark scaling 0.92 → 1 and fading in over
/// `medium`, then the first screen cross-fades in over `medium`. Nothing
/// loops. Reduced motion: the mark at full size and a 100 ms fade.
///
/// Cold start (TASK-14): the first screen is built only once the mark is in
/// place, so the first frame is just the mark (the native splash hands over
/// at once) and the first screen's heavy first build — Home plus first-use
/// font shaping — lands while nothing moves, before the cross-fade.
class LaunchGate extends StatefulWidget {
  const LaunchGate({super.key, required this.child});

  final Widget child;

  @override
  State<LaunchGate> createState() => LaunchGateState();
}

class LaunchGateState extends State<LaunchGate> with TickerProviderStateMixin {
  late final AnimationController markIn = AnimationController(vsync: this);
  late final AnimationController reveal = AnimationController(vsync: this);
  bool _done = false;
  bool _started = false;
  bool _childBuilt = false;

  /// Mark scale for tests.
  double get markScale {
    final from = SaartheeMotion.launchMarkScaleFrom;
    return from + (1 - from) * SaartheeMotion.standard.transform(markIn.value);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final scheme = SaartheeMotion.of(context);
    reveal.duration = scheme.medium.duration;
    if (!scheme.transforms) {
      markIn.value = 1;
      WidgetsBinding.instance.addPostFrameCallback((_) => _buildChild());
      return;
    }
    markIn.duration = scheme.medium.duration;
    markIn.forward().whenCompleteOrCancel(_buildChild);
  }

  /// Builds the first screen under the still mark, then reveals it after
  /// that (possibly long) frame has been drawn.
  void _buildChild() {
    if (!mounted) return;
    setState(() => _childBuilt = true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
  }

  void _reveal() {
    if (!mounted) return;
    reveal.forward().whenCompleteOrCancel(() {
      if (mounted) setState(() => _done = true);
    });
  }

  @override
  void dispose() {
    markIn.dispose();
    reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        if (_childBuilt) widget.child,
        if (!_done)
          Positioned.fill(
            child: IgnorePointer(
              child: FadeTransition(
                opacity: ReverseAnimation(reveal),
                child: ColoredBox(
                  key: const Key('launch.overlay'),
                  color: SaartheeColors.light.primary,
                  child: Center(
                    child: AnimatedBuilder(
                      animation: markIn,
                      builder: (context, child) => Opacity(
                        opacity: markIn.value,
                        child: Transform.scale(scale: markScale, child: child),
                      ),
                      child: const BrandMark(key: Key('launch.mark'), size: 96),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
