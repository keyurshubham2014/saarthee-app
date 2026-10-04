import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../motion/seen_once.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.dart';

/// Percentage bar for scorecards (TASK-09, reused by TASK-11's dashboard):
/// `primary` fill on a `surfaceAlt` pill track. On the first view of
/// [animateKey] in this session the fill grows from 0 over `long`
/// (transform `scaleX` from the start edge, clipped — no layout animation).
/// Rebuilds, new data, refreshes and later views show the final value at
/// once; reduced motion shows it at once too.
class ScorecardBar extends ConsumerStatefulWidget {
  const ScorecardBar({
    super.key,
    required this.fraction,
    required this.animateKey,
    this.height = 8,
    this.vertical = false,
  });

  /// 0..1 (clamped).
  final double fraction;

  /// Session key, e.g. `scorecard:<wardId>:verified`.
  final String animateKey;

  /// Bar thickness (its height when horizontal, its width when vertical).
  final double height;

  /// TASK-11: vertical column (trend chart) growing up from the baseline
  /// (`scaleY` from the bottom edge); fills the parent's height.
  final bool vertical;

  @override
  ConsumerState<ScorecardBar> createState() => _ScorecardBarState();
}

class _ScorecardBarState extends ConsumerState<ScorecardBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  late final bool _firstView = ref
      .read(seenOnceProvider)
      .markFirstView(widget.animateKey);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final scheme = SaartheeMotion.of(context);
    if (!_firstView || scheme.isReduced) {
      _c.value = 1;
      return;
    }
    _c.duration = scheme.long.duration;
    _c.forward(from: 0);
  }

  @override
  void didUpdateWidget(ScorecardBar old) {
    super.didUpdateWidget(old);
    if (old.fraction != widget.fraction ||
        old.animateKey != widget.animateKey) {
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final target = widget.fraction.clamp(0.0, 1.0);
    final radius = BorderRadius.circular(widget.height);
    if (widget.vertical) {
      return ExcludeSemantics(
        child: ClipRRect(
          borderRadius: radius,
          child: Container(
            width: widget.height,
            color: c.surfaceAlt,
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: target,
              widthFactor: 1,
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, child) => Transform.scale(
                  key: const Key('scorecardBar.fill'),
                  scaleX: 1,
                  scaleY: SaartheeMotion.long.curve.transform(_c.value),
                  alignment: Alignment.bottomCenter,
                  child: child,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.primary,
                    borderRadius: radius,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: radius,
        child: Container(
          height: widget.height,
          color: c.surfaceAlt,
          alignment: AlignmentDirectional.centerStart,
          child: FractionallySizedBox(
            widthFactor: target,
            heightFactor: 1,
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, child) => Transform.scale(
                key: const Key('scorecardBar.fill'),
                scaleX: SaartheeMotion.long.curve.transform(_c.value),
                scaleY: 1,
                alignment: AlignmentDirectional.centerStart.resolve(
                  Directionality.of(context),
                ),
                child: child,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: c.primary,
                  borderRadius: radius,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
