import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/icons.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/wards/ward_providers.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../onboarding/presentation/ward_picker_sheet.dart';
import '../../application/external_links.dart';
import '../../data/service_models.dart';

/// "Your ward office" card (TASK-12 §5.4): ward name, address, Call (tel:)
/// and Change ward; without a home ward, a prompt that opens the picker.
class WardOfficeCard extends ConsumerWidget {
  const WardOfficeCard({super.key, required this.office, required this.lang});

  final WardOffice? office;
  final String lang;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    final text = Theme.of(context).textTheme;
    final home = ref.watch(homeWardProvider);

    Future<void> pickWard() async {
      final picked = await showWardPicker(context);
      if (picked != null) {
        await ref.read(homeWardProvider.notifier).set(picked);
      }
    }

    final decoration = BoxDecoration(
      color: c.surface,
      borderRadius: AppRadii.cardRadius,
      border: Border.all(color: c.border, width: AppSpacing.borderWidth),
    );

    if (home == null) {
      return Container(
        key: const Key('service.setWard'),
        padding: const EdgeInsets.all(AppSpacing.s16),
        decoration: decoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.servicesSetWardPrompt, style: text.bodyMedium),
            const SizedBox(height: AppSpacing.s8),
            SecondaryButton(label: l10n.homeSetYourWard, onPressed: pickWard),
          ],
        ),
      );
    }

    final wardLabel = office == null
        ? l10n.wardDisplayName(home.number, home.name(lang))
        : l10n.wardDisplayName(office!.number, office!.name(lang));
    final address = office?.address(lang);
    final phone = office?.phone;
    return Container(
      key: const Key('service.wardOffice'),
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: decoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(SaartheeIcons.apartment, color: c.primary),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  l10n.servicesYourWardOffice,
                  style: text.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(wardLabel, style: text.bodyLarge),
          const SizedBox(height: AppSpacing.s4),
          Text(
            address ?? l10n.servicesOfficeAddressMissing,
            style: text.bodyMedium?.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: AppSpacing.s8),
          Wrap(
            spacing: AppSpacing.s8,
            children: [
              if (phone != null && phone.isNotEmpty)
                TertiaryButton(
                  key: const Key('service.call'),
                  label: l10n.servicesCall,
                  icon: SaartheeIcons.call,
                  onPressed: () => ref.read(externalLauncherProvider)(
                    Uri(scheme: 'tel', path: phone),
                    LaunchMode.externalApplication,
                  ),
                ),
              TertiaryButton(
                key: const Key('service.changeWard'),
                label: l10n.servicesChangeWard,
                onPressed: pickWard,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
