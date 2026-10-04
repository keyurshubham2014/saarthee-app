import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/settings/locale_controller.dart';
import '../../../core/theme/icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/wards/ward_providers.dart';
import '../../initiatives/application/initiatives_providers.dart';
import '../../initiatives/presentation/widgets/initiative_card.dart';
import 'widgets/service_tip_card.dart';

/// Home "Drives and services" (replaces placeholder P-03, TASK-12 §5.4):
/// seasonal tip, the next 2 drives for the home ward (hidden when none) and
/// four service shortcut tiles.
class HomeServicesSection extends ConsumerWidget {
  const HomeServicesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final lang = ref.watch(localeProvider).languageCode;
    final wardId = ref.watch(homeWardProvider.select((w) => w?.id));
    final drives =
        ref.watch(initiativesListProvider(wardId)).value?.value ?? const [];

    final shortcuts = <(Key, IconData, String, String)>[
      (
        const Key('home.shortcut.ptax'),
        SaartheeIcons.receipt,
        l10n.servicesShortcutPropertyTax,
        '/services/property-tax-pay',
      ),
      (
        const Key('home.shortcut.birth'),
        SaartheeIcons.badge,
        l10n.servicesShortcutBirthDeath,
        '/services/birth-death-search',
      ),
      (
        const Key('home.shortcut.kankaria'),
        SaartheeIcons.attractions,
        l10n.servicesShortcutKankaria,
        '/services/kankaria-tickets',
      ),
      (
        const Key('home.shortcut.all'),
        SaartheeIcons.services,
        l10n.servicesAllServices,
        '/services',
      ),
    ];

    return Column(
      key: const Key('home.servicesSection'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ServiceTipCard(),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.sectionTitleTop,
            AppSpacing.s8,
            AppSpacing.sectionTitleBottom,
          ),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(l10n.homeSectionDrives, style: text.titleLarge),
                ),
              ),
              if (drives.isNotEmpty)
                TextButton(
                  key: const Key('home.drives.seeAll'),
                  onPressed: () => context.push('/initiatives'),
                  child: Text(l10n.servicesSeeAll),
                ),
            ],
          ),
        ),
        for (final i in drives.take(2))
          InitiativeCard(
            initiative: i,
            lang: lang,
            onTap: () => context.push('/initiatives/${i.id}'),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.s8,
            AppSpacing.gutter,
            0,
          ),
          // Two tiles per row that grow with the text (Gujarati at 2.0×).
          child: Column(
            children: [
              for (var r = 0; r < shortcuts.length; r += 2)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.cardGap),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (k, icon, label, path)
                            in shortcuts.skip(r).take(2)) ...[
                          if (k != shortcuts[r].$1)
                            const SizedBox(width: AppSpacing.cardGap),
                          Expanded(
                            child: _ShortcutTile(
                              key: k,
                              icon: icon,
                              label: label,
                              onTap: () => context.push(path),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Service shortcut tile: radius 18, 1 px border, 40 dp icon badge (radius 14).
class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final text = Theme.of(context).textTheme;
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.cardRadius,
        side: BorderSide(color: c.border, width: AppSpacing.borderWidth),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: AppSpacing.categoryBadge,
                height: AppSpacing.categoryBadge,
                decoration: BoxDecoration(
                  color: c.primaryContainer,
                  borderRadius: AppRadii.controlRadius,
                ),
                child: Icon(icon, color: c.primaryDark),
              ),
              const SizedBox(height: AppSpacing.s12),
              Text(label, style: text.titleSmall),
            ],
          ),
        ),
      ),
    );
  }
}
