import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/settings/locale_controller.dart';
import '../../../../core/theme/icons.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/alerts/validity_format.dart';
import '../../../../core/widgets/widgets.dart';
import '../../shared/staff_shared.dart';
import '../application/staff_alerts_providers.dart';
import '../data/staff_alerts_api.dart';

/// `/staff/alerts` (REQ-F-035/036): Drafts (feed drafts badged), Awaiting
/// approval, Published, Ended.
class StaffAlertsListScreen extends StatelessWidget {
  const StaffAlertsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: StaffAlertsTab.values.length,
      child: StaffPageScaffold(
        title: l10n.staffAlertsTitle,
        floatingActionButton: FloatingActionButton.extended(
          key: const ValueKey('staffAlertsNew'),
          onPressed: () => context.push('/staff/alerts/new'),
          icon: const Icon(SaartheeIcons.add),
          label: Text(l10n.staffAlertsNew),
        ),
        body: Column(
          children: [
            TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: l10n.staffAlertsTabDrafts),
                Tab(text: l10n.staffAlertsTabPending),
                Tab(text: l10n.staffAlertsTabPublished),
                Tab(text: l10n.staffAlertsTabEnded),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  for (final t in StaffAlertsTab.values) _TabList(tab: t),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabList extends ConsumerWidget {
  const _TabList({required this.tab});

  final StaffAlertsTab tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    return ref
        .watch(staffAlertsListProvider(tab))
        .when(
          loading: () => const SkeletonList(count: 4),
          error: (_, _) => ErrorState(
            message: l10n.staffAlertsLoadError,
            onRetry: () => ref.invalidate(staffAlertsListProvider(tab)),
          ),
          data: (items) => items.isEmpty
              ? EmptyState(message: l10n.staffAlertsEmpty)
              : RefreshIndicator(
                  onRefresh: () =>
                      ref.refresh(staffAlertsListProvider(tab).future),
                  child: ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) =>
                        _Row(alert: items[i], lang: lang),
                  ),
                ),
        );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.alert, required this.lang});

  final StaffAlert alert;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tone = AlertSeverityStyle.of(alert.severity);
    final c = SaartheeColors.of(context);
    return ListTile(
      key: ValueKey('staffAlert.${alert.id}'),
      leading: Icon(tone.icon, color: c.isDark ? tone.tint : tone.solid),
      title: Text(alert.titleEn.isEmpty ? alert.titleGu : alert.titleEn),
      subtitle: Text(
        [
          alertSeverityLabel(l10n, alert.severity),
          formatAlertValidity(l10n, lang, alert.validFrom, alert.validTo),
          if (alert.status == 'pending_approval')
            l10n.staffAlertsApprovals(
              alert.approvals.length,
              alert.approvalsNeeded,
            ),
          if (alert.origin == 'sachet') l10n.staffAlertsFromSachet,
        ].join(' · '),
      ),
      trailing: const Icon(SaartheeIcons.chevronRight),
      onTap: () => context.push('/staff/alerts/${alert.id}'),
    );
  }
}
