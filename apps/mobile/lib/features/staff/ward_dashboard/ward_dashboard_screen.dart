import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/settings/locale_controller.dart';
import '../../../core/theme/icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../shared/rep_shared.dart';
import '../exports/staff_exports_screen.dart' show staffCsvSaverProvider;
import '../shared/staff_widgets.dart';
import 'rep_console_api.dart';
import 'ward_dashboard_models.dart';
import 'ward_dashboard_providers.dart';
import 'ward_dashboard_sections.dart';
import 'ward_trend.dart';

String _ymd(DateTime d) => d.toIso8601String().substring(0, 10);

/// `/staff/ward` — representative ward dashboard (TASK-11 §5.4, REQ-F-054):
/// ward switcher (scope wards only), 4 stat tiles, category × age table,
/// overdue list, hotspots, 12-week trend with a table toggle, CSV download.
/// Count-ups and bar growth run on the first view of a ward only (DS §6);
/// everything else keeps the console's `short` fades.
class WardDashboardScreen extends ConsumerWidget {
  const WardDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scope = ref.watch(wardScopeProvider);
    return StaffAsync<List<ScopeWard>>(
      value: scope,
      onRetry: () => ref.invalidate(wardScopeProvider),
      builder: (wards) {
        if (wards.isEmpty) {
          return EmptyState(
            key: const Key('wardDash.noScope'),
            icon: SaartheeIcons.navMyWard,
            message: l10n.wardDashNoScope,
          );
        }
        final picked = ref.watch(selectedWardProvider);
        final ward = wards.firstWhere(
          (w) => w.id == picked,
          orElse: () => wards.first,
        );
        return _Dashboard(wards: wards, ward: ward);
      },
    );
  }
}

class _Dashboard extends ConsumerWidget {
  const _Dashboard({required this.wards, required this.ward});

  final List<ScopeWard> wards;
  final ScopeWard ward;

  Future<void> _csv(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    try {
      final from = _ymd(DateTime(now.year, now.month, now.day - 90));
      final bytes = await ref
          .read(repConsoleApiProvider)
          .csv(ward.id, from, _ymd(now));
      await ref.read(staffCsvSaverProvider)(
        'saarthee-ward-${ward.number}-${_ymd(now).replaceAll('-', '')}.csv',
        bytes,
      );
      if (context.mounted) showSaartheeToast(context, l10n.wardDashDownloaded);
    } catch (e) {
      if (context.mounted) {
        showSaartheeToast(
          context,
          repErrorMessage(l10n, e),
          kind: ToastKind.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    final locale = Localizations.localeOf(context).languageCode;
    final async = ref.watch(wardDashboardProvider(ward.id));
    final header = Wrap(
      spacing: AppSpacing.s12,
      runSpacing: AppSpacing.s8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Content width, but never wider than the row: a long ward name or
        // large text ellipsizes instead of overflowing at 360 dp.
        IntrinsicWidth(
          child: DropdownButton<String>(
            key: const Key('wardDash.switcher'),
            isExpanded: true,
            value: ward.id,
            hint: Text(l10n.wardDashSwitchWard),
            onChanged: wards.length < 2
                ? null
                : (id) => ref.read(selectedWardProvider.notifier).select(id!),
            items: [
              for (final w in wards)
                DropdownMenuItem(
                  value: w.id,
                  child: Text(
                    l10n.wardDashWard(w.number, w.name(lang)),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
            ],
          ),
        ),
        SecondaryButton(
          key: const Key('wardDash.csv'),
          label: l10n.wardDashDownload,
          icon: SaartheeIcons.download,
          onPressed: () => _csv(context, ref),
        ),
      ],
    );
    return RefreshIndicator(
      onRefresh: () => ref.refresh(wardDashboardProvider(ward.id).future),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        children: [
          header,
          const SizedBox(height: AppSpacing.s12),
          StaffAsync(
            value: async,
            onRetry: () => ref.invalidate(wardDashboardProvider(ward.id)),
            builder: (r) {
              final d = r.data;
              return Column(
                key: Key('wardDash.body.${d.ward.id}'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (d.electionActive)
                    NoticeBanner(
                      key: const Key('wardDash.election'),
                      kind: NoticeKind.electionMode,
                      message: l10n.wardDashElection,
                      rounded: true,
                    ),
                  if (r.stale)
                    NoticeBanner(
                      key: const Key('wardDash.stale'),
                      kind: NoticeKind.offline,
                      message: l10n.wardDashStale(
                        Formatters.dateTime(d.generatedAt, locale),
                      ),
                      rounded: true,
                    ),
                  const SizedBox(height: AppSpacing.s12),
                  WardTotals(d: d),
                  StaffSectionTitle(l10n.wardDashByCategory),
                  if (d.open == 0)
                    Text(l10n.wardDashEmpty, key: const Key('wardDash.empty'))
                  else
                    CategoryAgeTable(d: d),
                  StaffSectionTitle(l10n.wardDashOverdueTitle),
                  OverdueList(d: d),
                  StaffSectionTitle(l10n.wardDashHotspots),
                  HotspotList(d: d),
                  StaffSectionTitle(l10n.wardDashTrend),
                  WardTrend(d: d),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
