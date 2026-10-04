import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/settings/locale_controller.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/wards/ward_providers.dart';
import '../../../core/widgets/widgets.dart';
import '../../onboarding/presentation/ward_picker_sheet.dart';
import '../../shell/placeholders.dart';

/// Home tab (branch 0): the green header with the Report card, then the
/// sections later tasks fill (P-01 nearby issues, P-02 alerts strip, P-03
/// drives and services).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const reportBranch = 2;
  static const alertsBranch = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final ward = ref.watch(homeWardProvider);
    final lang = ref.watch(localeProvider).languageCode;
    final text = Theme.of(context).textTheme;
    final shell = StatefulNavigationShell.maybeOf(context);

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
      body: CustomScrollView(
        key: const PageStorageKey('home.scroll'),
        slivers: [
          SliverToBoxAdapter(
            child: HomeHeader(
              wardLabel: ward == null
                  ? null
                  : l10n.wardDisplayName(ward.number, ward.name(lang)),
              onWardTap: () async {
                final picked = await showWardPicker(context);
                if (picked != null) {
                  await ref.read(homeWardProvider.notifier).set(picked);
                }
              },
              onReport: () => shell?.goBranch(reportBranch),
              onBell: () => shell?.goBranch(alertsBranch),
            ),
          ),
          SliverList.list(
            children: [
              sectionTitle(l10n.homeSectionAlerts),
              const PlaceholderSection(
                placeholderId: PlaceholderId.p02AlertsStrip,
              ),
              sectionTitle(l10n.homeSectionNearby),
              const PlaceholderSection(
                placeholderId: PlaceholderId.p01NearbyIssues,
              ),
              sectionTitle(l10n.homeSectionDrives),
              const PlaceholderSection(placeholderId: PlaceholderId.p03Drives),
              const SizedBox(height: AppSpacing.s40),
            ],
          ),
        ],
      ),
    );
  }
}
