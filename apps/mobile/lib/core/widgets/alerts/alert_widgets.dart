import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import '../chips.dart';

/// Severity banner (DS §2/§5) for alert detail and the in-app banner:
/// Critical = solid #B3261E with white text; others tinted, severity icon +
/// word, radius 18, no side bar. [ended] greys it out ("This alert has
/// ended." / cancelled).
class SeverityBanner extends StatelessWidget {
  const SeverityBanner({
    super.key,
    required this.severity,
    this.message,
    this.ended = false,
    this.trailing,
  });

  final AlertSeverity severity;

  /// Optional line under the severity word (ended / cancelled notice).
  final String? message;
  final bool ended;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    final text = Theme.of(context).textTheme;
    final tone = AlertSeverityStyle.of(severity);
    final solid = severity == AlertSeverity.critical && !ended;
    final bg = ended
        ? c.surfaceAlt
        : solid
        ? tone.solid
        : (c.isDark ? c.surfaceAlt : tone.tint);
    final fg = solid ? NeemFixed.white : c.textPrimary;
    final accent = ended
        ? c.textSecondary
        : solid
        ? NeemFixed.white
        : (c.isDark ? tone.tint : tone.solid);
    return Container(
      key: ValueKey('severityBanner.${severity.name}${ended ? '.ended' : ''}'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadii.cardRadius),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(tone.icon, color: accent, size: AppSpacing.iconSize),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alertSeverityLabel(l10n, severity),
                  style: text.titleSmall?.copyWith(color: accent),
                ),
                if (message != null) ...[
                  const SizedBox(height: AppSpacing.s4),
                  Text(message!, style: text.bodyMedium?.copyWith(color: fg)),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// "Source: `name` · Relayed by Saarthee" with an optional open-link action.
class SourceLine extends StatelessWidget {
  const SourceLine({super.key, required this.source, this.onOpen});

  final String source;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    final style = Theme.of(context).textTheme.bodySmall;
    final line = Text(
      l10n.componentAlertSource(source),
      style: onOpen == null
          ? style?.copyWith(color: c.textSecondary)
          : style?.copyWith(
              color: c.primary,
              decoration: TextDecoration.underline,
            ),
    );
    if (onOpen == null) return line;
    return Semantics(
      link: true,
      hint: l10n.alertsOpenSourceLink,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
          child: line,
        ),
      ),
    );
  }
}

/// The DS §1 independence line under alerts, services and hand-offs.
class IndependenceFooter extends StatelessWidget {
  const IndependenceFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s16),
      child: Text(
        AppLocalizations.of(context).alertsIndependenceLine,
        key: const ValueKey('independenceFooter'),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: c.textSecondary),
      ),
    );
  }
}
