import 'package:flutter/material.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/wards/ward.dart';
import '../../../../core/widgets/alerts/validity_format.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../alerts/data/alert_models.dart';
import '../application/staff_alerts_providers.dart';
import 'composer_fields.dart';

/// Area picker: Wards (multi-select chips) / Zone / Whole city.
class ComposerArea extends StatelessWidget {
  const ComposerArea({
    super.key,
    required this.draft,
    required this.wards,
    required this.zones,
    required this.lang,
    required this.onChanged,
    this.error,
  });

  final ComposerDraft draft;
  final List<Ward> wards;
  final List<Zone> zones;
  final String lang;
  final VoidCallback onChanged;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final d = draft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(l10n.staffAlertsFieldArea),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(
              value: 'wards',
              label: Text(l10n.staffAlertsAreaWards),
            ),
            ButtonSegment(value: 'zone', label: Text(l10n.staffAlertsAreaZone)),
            ButtonSegment(value: 'city', label: Text(l10n.staffAlertsAreaCity)),
          ],
          selected: {d.scope},
          showSelectedIcon: false,
          onSelectionChanged: (s) {
            d.scope = s.first;
            onChanged();
          },
        ),
        const SizedBox(height: AppSpacing.s8),
        if (d.scope == 'wards')
          Wrap(
            spacing: AppSpacing.s8,
            children: [
              for (final w in wards)
                FilterChip(
                  label: Text(w.shortLabel(lang)),
                  selected: d.wardIds.contains(w.id),
                  onSelected: (on) {
                    d.wardIds = on
                        ? [...d.wardIds, w.id]
                        : ([...d.wardIds]..remove(w.id));
                    onChanged();
                  },
                ),
            ],
          ),
        if (d.scope == 'zone')
          DropdownButton<String>(
            value: d.zoneId,
            isExpanded: true,
            hint: Text(l10n.staffAlertsAreaZone),
            items: [
              for (final z in zones)
                DropdownMenuItem(
                  value: z.id,
                  child: Text(lang == 'gu' ? z.nameGu : z.nameEn),
                ),
            ],
            onChanged: (v) {
              d.zoneId = v;
              onChanged();
            },
          ),
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: SaartheeColors.of(context).error),
          ),
      ],
    );
  }
}

/// Live citizen-card preview in English and Gujarati (W-08-06).
class ComposerPreview extends StatelessWidget {
  const ComposerPreview({super.key, required this.draft});

  final ComposerDraft draft;

  Widget _card(BuildContext context, String lang) {
    final l10n = AppLocalizations.of(context);
    final sev = parseSeverity(draft.severity);
    final title = lang == 'gu' ? draft.titleGu : draft.titleEn;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s8),
      child: AlertCard(
        key: ValueKey('composerPreview.$lang'),
        severity: sev,
        title: title,
        area: switch (draft.scope) {
          'city' => l10n.alertsAreaCity,
          'zone' => l10n.staffAlertsAreaZone,
          _ => l10n.alertsAreaWards('${draft.wardIds.length}'),
        },
        validity: formatAlertValidity(
          l10n,
          lang,
          draft.validFrom,
          draft.validTo,
        ),
        source: draft.sourceName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FieldLabel(AppLocalizations.of(context).staffAlertsPreview),
      Localizations.override(
        context: context,
        locale: const Locale('en'),
        child: Builder(builder: (c) => _card(c, 'en')),
      ),
      Localizations.override(
        context: context,
        locale: const Locale('gu'),
        child: Builder(builder: (c) => _card(c, 'gu')),
      ),
    ],
  );
}
