import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/motion/haptics.dart';
import '../../../../core/motion/pressable.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/theme/tokens.dart';

/// Pinned 56 dp `primary` button (never sunrise) whose label fades to an
/// in-button linear progress bar over `short` while [sending] (DS §6 verify
/// Send, mark fixed, staff actions). Disabled while sending; one light
/// haptic on press. Reduced motion: the progress bar appears at once.
class SendProgressButton extends ConsumerWidget {
  const SendProgressButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.sending = false,
    this.pinned = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool sending;
  final bool pinned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = SaartheeColors.of(context);
    final l10n = AppLocalizations.of(context);
    final spec = SaartheeMotion.of(context).short;
    final enabled = onPressed != null && !sending;
    final height = pinned
        ? AppSpacing.pinnedButtonHeight
        : AppSpacing.buttonHeight;
    final style = FilledButton.styleFrom(
      minimumSize: Size(AppSpacing.touchTarget, height),
      backgroundColor: c.primary,
      foregroundColor: c.onPrimary,
      disabledBackgroundColor: sending ? c.primaryDark : c.surfaceAlt,
      disabledForegroundColor: sending ? c.onPrimary : c.textDisabled,
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: sending ? l10n.issueActionsVerifySending : null,
      excludeSemantics: sending,
      child: Pressable(
        enabled: enabled,
        child: FilledButton(
          key: const Key('issueActions.send'),
          style: style,
          onPressed: enabled
              ? () {
                  ref.read(saartheeHapticsProvider).light();
                  onPressed!();
                }
              : null,
          child: AnimatedSwitcher(
            duration: spec.duration,
            switchInCurve: spec.curve,
            switchOutCurve: spec.curve,
            child: sending
                ? Padding(
                    key: const ValueKey('send.progress'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s24,
                    ),
                    child: ClipRRect(
                      borderRadius: AppRadii.controlRadius,
                      child: LinearProgressIndicator(
                        minHeight: AppSpacing.s4,
                        color: c.onPrimary,
                        backgroundColor: c.onPrimary.withValues(alpha: 0.3),
                      ),
                    ),
                  )
                : Text(label, key: const ValueKey('send.label')),
          ),
        ),
      ),
    );
  }
}
