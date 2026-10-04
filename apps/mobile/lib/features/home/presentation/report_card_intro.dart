import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/app_settings.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens.dart';

/// shared_preferences flag: the one-time sunrise ring has started (per
/// install, not per account; set even when motion is reduced).
const String reportPulseShownKey = 'saarthee.home.reportPulseShown';

/// Report card entrance (DS §6): springs in (scale 0.96 → 1 + fade,
/// `springIn`) on the first Home load of the session, and on a user's first
/// launch one `sunrise` ring expands from the card edge and fades out once
/// (`long`). Reduced motion: no spring, no ring; the flag is still set.
class ReportCardIntro extends ConsumerStatefulWidget {
  const ReportCardIntro({super.key, required this.child, this.animate = true});

  final Widget child;
  final bool animate;

  static const double scaleFrom = 0.96;

  /// How far the ring grows beyond the card edge.
  static const double ringSpread = 18;

  @override
  ConsumerState<ReportCardIntro> createState() => _ReportCardIntroState();
}

class _ReportCardIntroState extends ConsumerState<ReportCardIntro>
    with TickerProviderStateMixin {
  late final AnimationController _spring = AnimationController(vsync: this);
  late final AnimationController _ring = AnimationController(vsync: this);
  bool _started = false;
  bool _pulsing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final m = SaartheeMotion.of(context);
    if (widget.animate && m.transforms) {
      _spring.duration = m.springIn.duration;
      _spring.forward();
    } else {
      _spring.value = 1;
    }
    final prefs = ref.read(sharedPreferencesProvider);
    if (prefs.getBool(reportPulseShownKey) == true) return;
    prefs.setBool(reportPulseShownKey, true);
    if (m.isReduced) return;
    _pulsing = true;
    _ring.duration = m.long.duration;
    _ring.forward().whenComplete(() {
      if (mounted) setState(() => _pulsing = false);
    });
  }

  @override
  void dispose() {
    _spring.dispose();
    _ring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final spring = CurvedAnimation(
      parent: _spring,
      curve: SaartheeMotion.spring,
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (_pulsing)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                key: const Key('reportCard.pulse'),
                animation: _ring,
                builder: (_, _) => CustomPaint(
                  painter: _RingPainter(
                    t: Curves.easeOut.transform(_ring.value),
                    color: c.sunrise,
                  ),
                ),
              ),
            ),
          ),
        AnimatedBuilder(
          animation: _spring,
          builder: (_, child) => Opacity(
            opacity: _spring.value.clamp(0.0, 1.0),
            child: Transform.scale(
              scale:
                  ReportCardIntro.scaleFrom +
                  (1 - ReportCardIntro.scaleFrom) * spring.value,
              child: child,
            ),
          ),
          child: widget.child,
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.t, required this.color});

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final grow = ReportCardIntro.ringSpread * t;
    final rect = (Offset.zero & size).inflate(grow);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(AppRadii.control + grow)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = color.withValues(alpha: 0.7 * (1 - t)),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.t != t || old.color != color;
}
