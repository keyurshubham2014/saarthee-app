import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/tokens.dart';
import 'buttons.dart';

/// One-line independence notice shown on every citizen entry point.
class IndependenceNotice extends StatelessWidget {
  const IndependenceNotice({super.key, this.text});

  final String? text;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_rounded, color: AppColors.indigo, size: 20),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text ?? l10n.commonIndependenceNotice,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

/// Empty or error state: icon, message, optional action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.message,
    this.icon = Icons.inbox_rounded,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.inkMuted),
          const SizedBox(height: AppSpacing.md),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.lg),
            SecondaryButton(
              label: actionLabel!,
              onPressed: onAction,
              icon: Icons.refresh_rounded,
            ),
          ],
        ],
      ),
    );
  }
}

/// Skeleton block for loading lists (02 §9.3).
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.height = 64});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: AppColors.indigoTint,
        borderRadius: AppRadii.cardRadius,
      ),
    );
  }
}
