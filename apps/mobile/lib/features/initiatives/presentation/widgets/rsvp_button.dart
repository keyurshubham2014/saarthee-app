import 'package:flutter/material.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/motion/motion_check.dart';
import '../../../../core/motion/pressable.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/theme/tokens.dart';

/// DS §6 "Initiative RSVP" (TASK-12 §5.4 Motion): "I'm going" (filled
/// `primary`, radius 14) morphs — same size, no layout animation — into a
/// filled "You're going" pill (`primaryContainer`, `primaryDark` text) with a
/// leading check drawn by [MotionCheck], over `medium`; the label cross-fades
/// over `short`. Cancel reverses it. While [busy] the button shows progress
/// inside it. Reduced motion: the final state on the first frame.
class RsvpButton extends StatelessWidget {
  const RsvpButton({
    super.key,
    required this.going,
    required this.busy,
    required this.full,
    required this.onPressed,
  });

  final bool going;
  final bool busy;

  /// Full and not going: disabled "This drive is full".
  final bool full;
  final VoidCallback? onPressed;

  /// Pill radius for the fixed button height.
  static const double pillRadius = AppSpacing.buttonHeight / 2;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    final scheme = SaartheeMotion.of(context);
    final morph = scheme.isReduced ? Duration.zero : scheme.medium.duration;
    final fade = scheme.short.duration;
    final disabled = full && !going;
    final enabled = !busy && !disabled && !going && onPressed != null;
    final bg = disabled
        ? c.surfaceAlt
        : going
        ? c.primaryContainer
        : c.primary;
    final fg = disabled
        ? c.textDisabled
        : going
        ? c.primaryDark
        : c.onPrimary;
    final label = disabled
        ? l10n.initiativesFull
        : going
        ? l10n.initiativesYoureGoing
        : l10n.initiativesImGoing;
    final style = Theme.of(context).textTheme.labelLarge?.copyWith(color: fg);

    final Widget content = busy
        ? SizedBox.square(
            key: const Key('rsvp.progress'),
            dimension: AppSpacing.iconSize,
            child: CircularProgressIndicator(strokeWidth: 3, color: fg),
          )
        : AnimatedSwitcher(
            duration: fade,
            switchInCurve: SaartheeMotion.standard,
            switchOutCurve: SaartheeMotion.standard,
            child: Row(
              key: ValueKey(label),
              mainAxisSize: MainAxisSize.min,
              children: [
                if (going) ...[
                  MotionCheck(
                    key: const Key('rsvp.check'),
                    color: fg,
                    semanticLabel: '',
                    size: AppSpacing.iconSmall + AppSpacing.s4,
                  ),
                  const SizedBox(width: AppSpacing.s8),
                ],
                Flexible(
                  child: Text(
                    label,
                    key: const Key('rsvp.label'),
                    style: style,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );

    return Semantics(
      button: true,
      enabled: enabled,
      label: busy ? l10n.commonWorking : label,
      excludeSemantics: true,
      child: Pressable(
        enabled: enabled,
        child: AnimatedContainer(
          key: const Key('rsvp.button'),
          duration: morph,
          curve: SaartheeMotion.standard,
          height: AppSpacing.buttonHeight,
          width: double.infinity,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(
              going ? pillRadius : AppRadii.control,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: enabled ? onPressed : null,
              child: Center(child: content),
            ),
          ),
        ),
      ),
    );
  }
}
