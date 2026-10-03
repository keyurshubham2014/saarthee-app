import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/icons.dart';
import '../theme/motion.dart';
import '../theme/tokens.dart';

/// Localized word for an issue status (DS §2).
String issueStatusLabel(AppLocalizations l10n, IssueStatus s) => switch (s) {
  IssueStatus.reported => l10n.statusReported,
  IssueStatus.sent || IssueStatus.acknowledged => l10n.statusAcknowledged,
  IssueStatus.inProgress => l10n.statusInProgress,
  IssueStatus.markedFixed => l10n.statusFixed,
  IssueStatus.verified => l10n.statusVerified,
  IssueStatus.reopened => l10n.statusReopened,
  IssueStatus.rejected => l10n.statusRejected,
};

/// Localized word for an alert severity (DS §2).
String alertSeverityLabel(AppLocalizations l10n, AlertSeverity s) =>
    switch (s) {
      AlertSeverity.info => l10n.severityInfo,
      AlertSeverity.advisory => l10n.severityAdvisory,
      AlertSeverity.warning => l10n.severityWarning,
      AlertSeverity.critical => l10n.severityCritical,
    };

/// Tint background, solid text, Rounded icon and word: never colour alone.
class ToneChip extends StatelessWidget {
  const ToneChip({
    super.key,
    required this.tone,
    required this.label,
    this.solid = false,
  });

  final ToneStyle tone;
  final String label;

  /// Solid fill with white text (critical banner style).
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final bg = solid ? tone.solid : tone.chipBackground(c);
    final fg = solid ? NeemFixed.white : tone.chipForeground(c);
    final spec = SaartheeMotion.of(context).short;
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: spec.duration,
        curve: spec.curve,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s12,
          vertical: AppSpacing.s4,
        ),
        decoration: ShapeDecoration(
          color: bg,
          shape: StadiumBorder(
            side: c.isDark && !solid
                ? BorderSide(color: tone.solid)
                : BorderSide.none,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(tone.icon, size: AppSpacing.iconSmall, color: fg),
            const SizedBox(width: AppSpacing.s4),
            Flexible(
              child: Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Issue status pill (DS §5 chips).
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final IssueStatus status;

  @override
  Widget build(BuildContext context) => ToneChip(
    key: ValueKey('statusChip.${status.name}'),
    tone: IssueStatusStyle.of(status),
    label: issueStatusLabel(AppLocalizations.of(context), status),
  );
}

/// Alert severity pill; critical is solid with white text.
class SeverityChip extends StatelessWidget {
  const SeverityChip({super.key, required this.severity});

  final AlertSeverity severity;

  @override
  Widget build(BuildContext context) => ToneChip(
    key: ValueKey('severityChip.${severity.name}'),
    tone: AlertSeverityStyle.of(severity),
    label: alertSeverityLabel(AppLocalizations.of(context), severity),
    solid: severity == AlertSeverity.critical,
  );
}

/// Filter pill (DS §5): selected = `primaryContainer` with a check.
class AppFilterChip extends StatelessWidget {
  const AppFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      avatar: icon == null ? null : Icon(icon, size: AppSpacing.iconSmall),
      showCheckmark: icon == null,
      shape: const StadiumBorder(),
      side: BorderSide(color: selected ? c.primary : c.borderStrong),
      selectedColor: c.primaryContainer,
      labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: selected ? c.onPrimaryContainer : c.textPrimary,
      ),
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
  }
}

/// Small "Overdue" style tag (warning tint + icon + word).
class TagLabel extends StatelessWidget {
  const TagLabel({
    super.key,
    required this.label,
    required this.icon,
    required this.foreground,
    required this.background,
  });

  final String label;
  final IconData icon;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s8,
        vertical: 2,
      ),
      decoration: ShapeDecoration(
        color: background,
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: AppSpacing.s4),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}

/// Convenience: the warning-tinted "Overdue" tag.
class OverdueTag extends StatelessWidget {
  const OverdueTag({super.key});

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    return TagLabel(
      label: AppLocalizations.of(context).componentOverdue,
      icon: SaartheeIcons.schedule,
      foreground: c.warning,
      background: c.warningTint,
    );
  }
}
