import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/tokens.dart';

enum ComplaintStatus { fixed, notFixed, waiting, filed, reminded }

/// Colour, icon and word for each status (02 §2.1). Shared with
/// [BeforeAfterCard]'s stamp.
class StatusStyle {
  const StatusStyle(this.icon, this.foreground, this.background);

  final IconData icon;
  final Color foreground;
  final Color background;

  static StatusStyle of(ComplaintStatus s) => switch (s) {
    ComplaintStatus.fixed => const StatusStyle(
      Icons.check_rounded,
      AppColors.fixed,
      AppColors.fixedTint,
    ),
    ComplaintStatus.notFixed => const StatusStyle(
      Icons.close_rounded,
      AppColors.notFixed,
      AppColors.notFixedTint,
    ),
    ComplaintStatus.waiting => const StatusStyle(
      Icons.hourglass_top_rounded,
      AppColors.ink,
      AppColors.waitingTint,
    ),
    ComplaintStatus.filed => const StatusStyle(
      Icons.description_rounded,
      AppColors.indigo,
      AppColors.indigoTint,
    ),
    ComplaintStatus.reminded => const StatusStyle(
      Icons.send_rounded,
      AppColors.ink,
      AppColors.waitingTint,
    ),
  };

  static String label(AppLocalizations l10n, ComplaintStatus s) => switch (s) {
    ComplaintStatus.fixed => l10n.statusFixed,
    ComplaintStatus.notFixed => l10n.statusNotFixed,
    ComplaintStatus.waiting => l10n.statusWaiting,
    ComplaintStatus.filed => l10n.statusFiled,
    ComplaintStatus.reminded => l10n.statusReminded,
  };
}

/// Status pill: always icon + word, never colour alone.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final ComplaintStatus status;

  @override
  Widget build(BuildContext context) {
    final style = StatusStyle.of(status);
    final label = StatusStyle.label(AppLocalizations.of(context), status);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(AppRadii.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 18, color: style.foreground),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: style.foreground),
          ),
        ],
      ),
    );
  }
}
