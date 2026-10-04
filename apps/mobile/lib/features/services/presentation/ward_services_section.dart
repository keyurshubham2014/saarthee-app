import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/settings/locale_controller.dart';
import '../../../core/theme/icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/wards/ward_providers.dart';
import '../../../core/widgets/widgets.dart';
import '../../initiatives/application/initiatives_providers.dart';
import '../../initiatives/presentation/widgets/initiative_card.dart';
import '../application/services_providers.dart';
import 'widgets/service_badges.dart';
import 'widgets/ward_office_card.dart';

/// My Ward "Services and drives" (replaces placeholder P-08, TASK-12 §5.4):
/// three services that need a ward office visit, the ward office card and
/// the next three drives for the ward.
class WardServicesSection extends ConsumerWidget {
  const WardServicesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    final text = Theme.of(context).textTheme;
    final lang = ref.watch(localeProvider).languageCode;
    final wardId = ref.watch(homeWardProvider.select((w) => w?.id));
    final services = (ref.watch(servicesListProvider).value?.value ?? const [])
        .where((s) => s.visitWardOffice)
        .take(3)
        .toList();
    final office = services.isEmpty
        ? null
        : ref
              .watch(serviceDetailProvider(services.first.slug))
              .value
              ?.wardOffice;
    final drives =
        ref.watch(initiativesListProvider(wardId)).value?.value ?? const [];

    Widget subTitle(String label) => Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.s16,
        AppSpacing.gutter,
        AppSpacing.s8,
      ),
      child: Text(
        label,
        style: text.titleMedium?.copyWith(color: c.textSecondary),
      ),
    );

    return Column(
      key: const Key('myWard.servicesSection'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
          child: WardOfficeCard(office: office, lang: lang),
        ),
        if (services.isNotEmpty) subTitle(l10n.servicesWardOfficeServices),
        for (final s in services)
          ServiceRow(
            service: s,
            lang: lang,
            onTap: () => context.push('/services/${s.slug}'),
          ),
        ListRow(
          key: const Key('myWard.allServices'),
          leading: Icon(SaartheeIcons.services, color: c.primary),
          title: l10n.servicesAllServices,
          onTap: () => context.push('/services'),
        ),
        if (drives.isNotEmpty) subTitle(l10n.servicesUpcomingDrives),
        for (final i in drives.take(3))
          InitiativeCard(
            initiative: i,
            lang: lang,
            onTap: () => context.push('/initiatives/${i.id}'),
          ),
        ListRow(
          key: const Key('myWard.allDrives'),
          leading: Icon(SaartheeIcons.event, color: c.primary),
          title: l10n.initiativesTitle,
          onTap: () => context.push('/initiatives'),
        ),
      ],
    );
  }
}
