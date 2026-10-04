import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../motion/haptics.dart';
import '../motion/pressable.dart';
import '../theme/tokens.dart';

/// Filled `primary` action (DS §5): 50 dp (56 dp when [pinned]), radius 14,
/// sentence case, verb first, one per screen. While [isLoading] it shows
/// progress inside the button, is disabled and announces "Working".
/// Press: scale 0.97 + light haptic.
class PrimaryButton extends ConsumerWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.pinned = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final bool pinned;

  @override
  Widget build(BuildContext context, WidgetRef ref) => _FilledAction(
    label: label,
    onPressed: onPressed,
    isLoading: isLoading,
    icon: icon,
    pinned: pinned,
    sunrise: false,
    haptics: ref.read(saartheeHapticsProvider),
  );
}

/// "Submit report": the only button in `sunrise` (DS §2 rule).
class SubmitReportButton extends ConsumerWidget {
  const SubmitReportButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context, WidgetRef ref) => _FilledAction(
    label: label,
    onPressed: onPressed,
    isLoading: isLoading,
    icon: null,
    pinned: true,
    sunrise: true,
    haptics: ref.read(saartheeHapticsProvider),
  );
}

class _FilledAction extends StatelessWidget {
  const _FilledAction({
    required this.label,
    required this.onPressed,
    required this.isLoading,
    required this.icon,
    required this.pinned,
    required this.sunrise,
    required this.haptics,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final bool pinned;
  final bool sunrise;
  final SaartheeHaptics haptics;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    final enabled = onPressed != null && !isLoading;
    final height = pinned
        ? AppSpacing.pinnedButtonHeight
        : AppSpacing.buttonHeight;
    final fg = sunrise ? c.onSunrise : c.onPrimary;
    final style =
        FilledButton.styleFrom(
          minimumSize: Size(AppSpacing.touchTarget, height),
          backgroundColor: sunrise ? c.sunrise : c.primary,
          foregroundColor: fg,
          disabledBackgroundColor: isLoading
              ? (sunrise ? c.sunrisePressed : c.primaryDark)
              : c.surfaceAlt,
          disabledForegroundColor: isLoading ? fg : c.textDisabled,
        ).copyWith(
          overlayColor: WidgetStatePropertyAll(
            (sunrise ? c.sunrisePressed : c.primaryDark).withValues(alpha: 0.4),
          ),
        );
    return Semantics(
      button: true,
      enabled: enabled,
      label: isLoading ? l10n.commonWorking : null,
      excludeSemantics: isLoading,
      child: Pressable(
        enabled: enabled,
        child: FilledButton(
          style: style,
          onPressed: enabled
              ? () {
                  haptics.light();
                  onPressed!();
                }
              : null,
          child: isLoading
              ? SizedBox.square(
                  dimension: AppSpacing.iconSize,
                  child: CircularProgressIndicator(strokeWidth: 3, color: fg),
                )
              : _Label(label: label, icon: icon),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: AppSpacing.iconSize),
          const SizedBox(width: AppSpacing.s8),
        ],
        Flexible(child: Text(label, textAlign: TextAlign.center)),
      ],
    );
  }
}

/// Outlined secondary action: 1.5 px `borderStrong`, `primary` text.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final enabled = onPressed != null && !isLoading;
    return Semantics(
      label: isLoading ? l10n.commonWorking : null,
      excludeSemantics: isLoading,
      button: true,
      enabled: enabled,
      child: Pressable(
        enabled: enabled,
        child: OutlinedButton(
          onPressed: enabled ? onPressed : null,
          child: isLoading
              ? const SizedBox.square(
                  dimension: AppSpacing.iconSize,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : _Label(label: label, icon: icon),
        ),
      ),
    );
  }
}

/// Text (tertiary) action, ≥ 48 dp.
class TertiaryButton extends StatelessWidget {
  const TertiaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      child: _Label(label: label, icon: icon),
    );
  }
}
