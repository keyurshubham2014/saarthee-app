import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/motion/motion_check.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens.dart';

/// "Signed in" with the drawn check (DS §6 `drawCheck`) shown in the button
/// area after the code is accepted; the text keeps the meaning without motion.
class SignedInCheck extends StatelessWidget {
  const SignedInCheck({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    return SizedBox(
      key: const Key('auth.signedInCheck'),
      height: AppSpacing.pinnedButtonHeight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          MotionCheck(
            color: c.primary,
            semanticLabel: l10n.authSignedIn,
            size: 28,
          ),
          const SizedBox(width: AppSpacing.s8),
          Text(
            l10n.authSignedIn,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

/// How long the route waits for the check before popping: the check's delay
/// plus its draw time (≈ 600 ms); zero with reduced motion (next frame).
Duration signedInCheckWait(BuildContext context) {
  final scheme = SaartheeMotion.of(context);
  return scheme.drawCheckDelay + scheme.drawCheck.duration;
}
