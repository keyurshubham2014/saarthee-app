import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/motion/motion_widgets.dart';
import '../../../../core/theme/tokens.dart';

/// Full-screen success top (DS §6 "Submit report → success"): the `success`
/// circle scales 0 → 1 (`springIn`), the white check draws (`drawCheck`,
/// 150 ms after the circle starts), [issueNumber] fades up (`rise`) after the
/// check. One success haptic when the check starts drawing (also with
/// reduced motion). No confetti, nothing loops.
class ReportSuccessHero extends ConsumerStatefulWidget {
  const ReportSuccessHero({
    super.key,
    required this.checkLabel,
    required this.issueNumber,
  });

  static const double circleSize = 96;

  final String checkLabel;
  final Widget issueNumber;

  @override
  ConsumerState<ReportSuccessHero> createState() => ReportSuccessHeroState();
}

class ReportSuccessHeroState extends ConsumerState<ReportSuccessHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _circle = AnimationController(vsync: this);
  Timer? _haptic;
  bool _started = false;

  /// Current circle scale (tests).
  double get circleScale => SaartheeMotion.spring.transform(_circle.value);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final scheme = SaartheeMotion.of(context);
    final haptics = ref.read(saartheeHapticsProvider);
    if (scheme.springIn.isInstant) {
      _circle.value = 1;
    } else {
      _circle.duration = scheme.springIn.duration;
      _circle.forward();
    }
    // The check starts drawing after drawCheckDelay (at once when reduced).
    if (scheme.drawCheckDelay == Duration.zero) {
      haptics.success();
    } else {
      _haptic = Timer(scheme.drawCheckDelay, () => haptics.success());
    }
  }

  @override
  void dispose() {
    _haptic?.cancel();
    _circle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final scheme = SaartheeMotion.of(context);
    final afterCheck = scheme.drawCheckDelay + scheme.drawCheck.duration;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _circle,
          builder: (context, child) =>
              Transform.scale(scale: circleScale, child: child),
          child: Container(
            key: const Key('report.success.circle'),
            width: ReportSuccessHero.circleSize,
            height: ReportSuccessHero.circleSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.success, shape: BoxShape.circle),
            child: MotionCheck(
              color: c.onPrimary,
              semanticLabel: widget.checkLabel,
              size: 56,
              strokeWidth: 5,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s24),
        RiseIn(
          key: const Key('report.success.number'),
          delay: afterCheck,
          child: widget.issueNumber,
        ),
      ],
    );
  }
}
