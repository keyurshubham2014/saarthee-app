import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/icons.dart';
import '../theme/motion.dart';
import '../theme/tokens.dart';

/// Step header (DS §5): Close/Back, "Step n of total" with a hint of the
/// next step, a painted progress bar that animates to its new value
/// (`medium`, clipped, no layout animation), announced to TalkBack.
class StepHeader extends StatelessWidget {
  const StepHeader({
    super.key,
    required this.step,
    required this.total,
    this.nextHint,
    this.onBack,
    this.onClose,
  });

  final int step;
  final int total;
  final String? nextHint;
  final VoidCallback? onBack;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    final text = Theme.of(context).textTheme;
    final spec = SaartheeMotion.of(context).medium;
    final label = l10n.commonStepOf(step, total);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (onClose != null)
              IconButton(
                tooltip: l10n.commonClose,
                icon: const Icon(SaartheeIcons.close),
                onPressed: onClose,
              )
            else if (onBack != null)
              IconButton(
                tooltip: l10n.commonBack,
                icon: const Icon(SaartheeIcons.back),
                onPressed: onBack,
              ),
            Expanded(
              child: Semantics(
                liveRegion: true,
                label: label,
                excludeSemantics: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: text.labelLarge),
                    if (nextHint != null)
                      Text(
                        l10n.componentStepNext(nextHint!),
                        style: text.bodySmall,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s8),
        TweenAnimationBuilder<double>(
          tween: Tween(end: total == 0 ? 0 : step / total),
          duration: spec.duration,
          curve: spec.curve,
          builder: (context, value, _) => ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.s4),
            child: CustomPaint(
              key: const Key('stepHeader.progress'),
              size: const Size.fromHeight(6),
              painter: _ProgressPainter(
                value: value,
                track: c.surfaceAlt,
                fill: c.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressPainter extends CustomPainter {
  const _ProgressPainter({
    required this.value,
    required this.track,
    required this.fill,
  });

  final double value;
  final Color track;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = track);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width * value.clamp(0.0, 1.0), size.height),
      Paint()..color = fill,
    );
  }

  @override
  bool shouldRepaint(_ProgressPainter old) =>
      old.value != value || old.track != track || old.fill != fill;
}
