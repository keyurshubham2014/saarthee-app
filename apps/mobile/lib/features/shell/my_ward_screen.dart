import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/settings/locale_controller.dart';
import '../../core/theme/icons.dart';
import '../../core/theme/tokens.dart';
import '../../core/wards/ward_providers.dart';
import '../../core/widgets/widgets.dart';
import '../me/presentation/me_row.dart';
import '../onboarding/presentation/ward_picker_sheet.dart';
import '../services/presentation/ward_services_section.dart';
import 'placeholders.dart';

/// My Ward tab (branch 4): ward header, Settings and About rows, and the
/// sections later tasks fill (P-07 representatives, P-08 ward services,
/// P-09 profile).
class MyWardScreen extends ConsumerWidget {
  const MyWardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    final text = Theme.of(context).textTheme;
    final ward = ref.watch(homeWardProvider);
    final lang = ref.watch(localeProvider).languageCode;

    Future<void> pickWard() async {
      final picked = await showWardPicker(context);
      if (picked != null) {
        await ref.read(homeWardProvider.notifier).set(picked);
      }
    }

    Widget sectionTitle(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.sectionTitleTop,
        AppSpacing.gutter,
        AppSpacing.sectionTitleBottom,
      ),
      child: Semantics(
        header: true,
        child: Text(title, style: text.titleLarge),
      ),
    );

    return Scaffold(
      appBar: SaartheeAppBar(
        title: l10n.navMyWard,
        subtitle: ward?.zone.name(lang).isNotEmpty == true
            ? l10n.wardZone(ward!.zone.name(lang))
            : null,
        showBack: false,
      ),
      body: ListView(
        key: const PageStorageKey('myWard.scroll'),
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.gutter),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.s16),
              decoration: AppElevation.cardDecoration(c),
              child: Row(
                children: [
                  Icon(SaartheeIcons.navMyWard, color: c.primary),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Text(
                      ward == null
                          ? l10n.myWardNoWard
                          : l10n.wardDisplayName(ward.number, ward.name(lang)),
                      style: text.titleMedium,
                    ),
                  ),
                  TextButton(
                    key: const Key('myWard.change'),
                    onPressed: pickWard,
                    child: Text(
                      ward == null ? l10n.homeSetYourWard : l10n.commonChange,
                    ),
                  ),
                ],
              ),
            ),
          ),
          sectionTitle(l10n.myWardSectionRepresentatives),
          const PlaceholderSection(
            placeholderId: PlaceholderId.p07Representatives,
          ),
          sectionTitle(l10n.myWardSectionServices),
          // TASK-12: replaces placeholder P-08.
          const WardServicesSection(),
          sectionTitle(l10n.myWardSectionYou),
          // TASK-04: replaces placeholder P-09.
          const MeRow(),
          const Divider(),
          ListRow(
            key: const Key('myWard.settings'),
            leading: Icon(SaartheeIcons.settings, color: c.textSecondary),
            title: l10n.settingsTitle,
            onTap: () => context.push('/me/settings'),
          ),
          ListRow(
            key: const Key('myWard.about'),
            leading: Icon(SaartheeIcons.info, color: c.textSecondary),
            title: l10n.aboutTitle,
            onTap: () => context.push('/about'),
          ),
          const SizedBox(height: AppSpacing.s24),
        ],
      ),
    );
  }
}
