import 'package:flutter/material.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/icons.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/service_models.dart';

/// "Online" (`language`) and "Visit ward office" (`apartment`) pill badges.
class ServiceBadges extends StatelessWidget {
  const ServiceBadges({super.key, required this.service});

  final ServiceSummary service;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    return Wrap(
      spacing: AppSpacing.s8,
      runSpacing: AppSpacing.s4,
      children: [
        if (service.online)
          TagLabel(
            key: const Key('services.badge.online'),
            label: l10n.servicesBadgeOnline,
            icon: SaartheeIcons.globe,
            foreground: c.primaryDark,
            background: c.primaryContainer,
          ),
        if (service.visitWardOffice)
          TagLabel(
            key: const Key('services.badge.wardOffice'),
            label: l10n.servicesBadgeWardOffice,
            icon: SaartheeIcons.apartment,
            foreground: c.textPrimary,
            background: c.infoTint,
          ),
      ],
    );
  }
}

/// Category chip label.
String serviceCategoryLabel(AppLocalizations l10n, String? category) =>
    switch (category) {
      null => l10n.servicesCategoryAll,
      'tax' => l10n.servicesCategoryTax,
      'certificates' => l10n.servicesCategoryCertificates,
      'building' => l10n.servicesCategoryBuilding,
      'health' => l10n.servicesCategoryHealth,
      'education' => l10n.servicesCategoryEducation,
      'transport' => l10n.servicesCategoryTransport,
      'leisure' => l10n.servicesCategoryLeisure,
      'information' => l10n.servicesCategoryInformation,
      _ => l10n.servicesCategoryBusiness,
    };

/// A service as a bordered card row (radius 18, 1 px border): name,
/// summary and badges.
class ServiceRow extends StatelessWidget {
  const ServiceRow({
    super.key,
    required this.service,
    required this.lang,
    required this.onTap,
  });

  final ServiceSummary service;
  final String lang;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final text = Theme.of(context).textTheme;
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
          key: Key('services.row.${service.slug}'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(service.name(lang), style: text.titleMedium),
                      const SizedBox(height: AppSpacing.s4),
                      Text(service.summary(lang), style: text.bodySmall),
                      if (service.online || service.visitWardOffice) ...[
                        const SizedBox(height: AppSpacing.s8),
                        ServiceBadges(service: service),
                      ],
                    ],
                  ),
                ),
                Icon(SaartheeIcons.chevronRight, color: c.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
