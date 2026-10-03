import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/tokens.dart';

/// "You're offline. Your answers are saved." with an optional retry (02 §9.2).
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, this.onRetry, this.message});

  final VoidCallback? onRetry;

  /// Overrides the default offline text (e.g. a rate-limit wait message).
  final String? message;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        color: AppColors.waitingTint,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screen,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded, color: AppColors.ink),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                message ?? l10n.commonOfflineBanner,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: Text(l10n.commonRetry)),
          ],
        ),
      ),
    );
  }
}
