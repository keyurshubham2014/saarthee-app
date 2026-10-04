import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/icons.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/initiative_models.dart';

IconData initiativeTypeIcon(String type) => switch (type) {
  'tree_drive' => SaartheeIcons.park,
  'cleanup' => SaartheeIcons.cleaning,
  'health_camp' => SaartheeIcons.medical,
  _ => SaartheeIcons.event,
};

String initiativeTypeLabel(AppLocalizations l10n, String type) =>
    switch (type) {
      'tree_drive' => l10n.initiativesTypeTreeDrive,
      'cleanup' => l10n.initiativesTypeCleanup,
      'health_camp' => l10n.initiativesTypeHealthCamp,
      _ => l10n.initiativesTypeOther,
    };

/// "Sun 12 Oct, 7:00–9:00 am" in IST for [locale].
String initiativeWhen(AppLocalizations l10n, Initiative i, String locale) {
  final start = Formatters.toIst(i.startsAt);
  final end = Formatters.toIst(i.endsAt);
  final date = DateFormat('EEE d MMM', locale).format(start);
  final time = DateFormat.jm(locale);
  return l10n.initiativesTimeRange(
    date,
    time.format(start).toLowerCase(),
    time.format(end).toLowerCase(),
  );
}

/// Initiative card (radius 18, 1 px border): type icon + label, title,
/// when, place, organiser and going count.
class InitiativeCard extends StatelessWidget {
  const InitiativeCard({
    super.key,
    required this.initiative,
    required this.lang,
    required this.onTap,
  });

  final Initiative initiative;
  final String lang;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    final text = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final i = initiative;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.gutter,
        vertical: AppSpacing.s4,
      ),
      child: Material(
        color: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.cardRadius,
          side: BorderSide(color: c.border, width: AppSpacing.borderWidth),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('initiative.card.${i.id}'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      initiativeTypeIcon(i.type),
                      color: c.primary,
                      size: AppSpacing.iconSmall,
                    ),
                    const SizedBox(width: AppSpacing.s4),
                    Text(
                      initiativeTypeLabel(l10n, i.type),
                      style: text.labelMedium?.copyWith(color: c.primaryDark),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s8),
                Text(i.title(lang), style: text.titleMedium),
                const SizedBox(height: AppSpacing.s4),
                Text(initiativeWhen(l10n, i, locale), style: text.bodyMedium),
                Text(i.place(lang), style: text.bodySmall),
                const SizedBox(height: AppSpacing.s8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.initiativesBy(i.organiserName),
                        style: text.bodySmall?.copyWith(color: c.textSecondary),
                      ),
                    ),
                    Text(
                      l10n.initiativesGoing(i.goingCount),
                      style: text.labelMedium,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
