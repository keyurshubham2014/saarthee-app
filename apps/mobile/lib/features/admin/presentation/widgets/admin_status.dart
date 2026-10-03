import 'package:flutter/material.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/icons.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/formatters.dart';

/// v1 complaint stamp states, kept for the admin console until TASK-10
/// replaces it (the citizen app uses `IssueStatus` + `StatusChip`).
enum AdminStampStatus { fixed, notFixed, waiting, filed }

/// Colour, icon and word for a stamp: always icon + word, never colour alone.
class AdminStampStyle {
  const AdminStampStyle(this.icon, this.foreground, this.background);

  final IconData icon;
  final Color foreground;
  final Color background;

  static AdminStampStyle of(SaartheeColors c, AdminStampStatus s) =>
      switch (s) {
        AdminStampStatus.fixed => AdminStampStyle(
          SaartheeIcons.check,
          c.success,
          c.successTint,
        ),
        AdminStampStatus.notFixed => AdminStampStyle(
          SaartheeIcons.close,
          c.error,
          c.errorTint,
        ),
        AdminStampStatus.waiting => AdminStampStyle(
          SaartheeIcons.hourglass,
          c.textPrimary,
          c.warningTint,
        ),
        AdminStampStatus.filed => AdminStampStyle(
          SaartheeIcons.description,
          c.primary,
          c.primaryContainer,
        ),
      };

  static String label(AppLocalizations l10n, AdminStampStatus s) => switch (s) {
    AdminStampStatus.fixed => l10n.statusFixed,
    AdminStampStatus.notFixed => l10n.statusNotFixed,
    AdminStampStatus.waiting => l10n.statusWaiting,
    AdminStampStatus.filed => l10n.statusFiled,
  };
}

class _PhotoFrame extends StatelessWidget {
  const _PhotoFrame({required this.image, required this.semanticLabel});

  final ImageProvider? image;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    Widget placeholder() => Container(
      color: c.surfaceAlt,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(AppSpacing.s8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(SaartheeIcons.hideImage, color: c.textSecondary),
          const SizedBox(height: AppSpacing.s4),
          Text(
            l10n.photoMissing,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: ClipRRect(
        borderRadius: AppRadii.controlRadius,
        child: image == null
            ? placeholder()
            : Image(
                image: image!,
                fit: BoxFit.cover,
                semanticLabel: semanticLabel,
                errorBuilder: (_, _, _) => placeholder(),
              ),
      ),
    );
  }
}

/// Report photo and latest verification photo side by side, with the status
/// stamp across the bottom (v1 02 §2.5, restyled to Neem).
class AdminBeforeAfterCard extends StatelessWidget {
  const AdminBeforeAfterCard({
    super.key,
    required this.before,
    required this.after,
    required this.status,
    this.beforeDate,
    this.afterDate,
    this.beforeOnly = false,
  });

  final ImageProvider? before;
  final ImageProvider? after;
  final DateTime? beforeDate;
  final DateTime? afterDate;
  final AdminStampStatus status;
  final bool beforeOnly;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    final theme = Theme.of(context);
    final style = AdminStampStyle.of(c, status);
    final statusWord = AdminStampStyle.label(l10n, status);
    final beforeLabel = beforeDate == null
        ? null
        : l10n.photoReportedOn(Formatters.shortDate(beforeDate!));
    final afterLabel = afterDate == null
        ? null
        : l10n.photoNowOn(Formatters.shortDate(afterDate!));

    Widget column(ImageProvider? img, String? label) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PhotoFrame(image: img, semanticLabel: label ?? l10n.photoMissing),
          if (label != null) ...[
            const SizedBox(height: AppSpacing.s4),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );

    return Semantics(
      container: true,
      label: [?beforeLabel, ?afterLabel, statusWord].join(', '),
      child: Container(
        decoration: AppElevation.cardDecoration(c),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.s8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  column(before, beforeLabel),
                  const SizedBox(width: AppSpacing.s8),
                  if (beforeOnly)
                    const Expanded(child: SizedBox.shrink())
                  else
                    column(after, afterLabel),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s12,
                vertical: AppSpacing.s8,
              ),
              decoration: BoxDecoration(
                color: style.background,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(AppRadii.card),
                ),
                border: Border(
                  top: BorderSide(
                    color: style.foreground,
                    width: AppSpacing.focusWidth,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(style.icon, color: style.foreground),
                  const SizedBox(width: AppSpacing.s4),
                  Flexible(
                    child: Text(
                      statusWord,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: style.foreground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
