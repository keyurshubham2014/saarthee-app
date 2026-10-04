import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../shared/staff_api.dart';
import '../shared/staff_shared.dart';
import '../shared/staff_widgets.dart';

/// `GET /staff/summary`.
class StaffSummary {
  const StaffSummary({required this.sensitive, required this.flagged, required this.outside, required this.alerts});

  factory StaffSummary.fromJson(Json j) {
    final q = (j['queues'] as Map).cast<String, dynamic>();
    int n(Object? v) => (v as num?)?.toInt() ?? 0;
    return StaffSummary(
      sensitive: n(q['sensitive']),
      flagged: n(q['flagged']),
      outside: n(q['outOfArea']),
      alerts: n(j['alertsAwaitingApproval']),
    );
  }

  final int sensitive, flagged, outside, alerts;
  bool get allClear => sensitive + flagged + outside + alerts == 0;
}

final staffSummaryProvider = FutureProvider.autoDispose<StaffSummary>(
  (ref) async => StaffSummary.fromJson(await ref.watch(staffApiProvider).summary()),
);

/// Dashboard (TASK-10 §5.4): count cards linking to their lists. Counts are
/// static (no count-up, DS §6 staff row).
class StaffDashboardScreen extends ConsumerWidget {
  const StaffDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final summary = ref.watch(staffSummaryProvider);
    return StaffPageScaffold(
      title: l10n.staffDashTitle,
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(staffSummaryProvider.future),
        child: StaffAsync<StaffSummary>(
          value: summary,
          onRetry: () => ref.invalidate(staffSummaryProvider),
          builder: (s) => ListView(
            padding: const EdgeInsets.all(AppSpacing.gutter),
            children: [
              if (s.allClear)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s16),
                  child: NoticeBanner(key: const Key('staff.dash.allClear'), kind: NoticeKind.info, message: l10n.staffDashAllClear, rounded: true),
                ),
              Wrap(
                spacing: AppSpacing.cardGap,
                runSpacing: AppSpacing.cardGap,
                children: [
                  _CountCard(id: 'sensitive', label: l10n.staffDashSensitive, count: s.sensitive, icon: SaartheeIcons.privacy, route: '/staff/moderation?tab=sensitive'),
                  _CountCard(id: 'flagged', label: l10n.staffDashFlagged, count: s.flagged, icon: SaartheeIcons.flag, route: '/staff/moderation?tab=flagged'),
                  _CountCard(id: 'outside', label: l10n.staffDashOutside, count: s.outside, icon: SaartheeIcons.locationOff, route: '/staff/moderation?tab=out_of_area'),
                  _CountCard(id: 'alerts', label: l10n.staffDashAlerts, count: s.alerts, icon: SaartheeIcons.navAlerts, route: '/staff/alerts'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({required this.id, required this.label, required this.count, required this.icon, required this.route});

  final String id;
  final String label;
  final int count;
  final IconData icon;
  final String route;

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final text = Theme.of(context).textTheme;
    return SizedBox(
      width: 260,
      child: Material(
        color: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: BorderSide(color: c.border),
        ),
        child: InkWell(
          key: Key('staff.dash.$id'),
          customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.card)),
          onTap: () => context.go(route),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: c.primary),
                const SizedBox(height: AppSpacing.s12),
                Text('$count', key: Key('staff.dash.$id.count'), style: text.displaySmall),
                const SizedBox(height: AppSpacing.s4),
                Text(label, style: text.bodyMedium?.copyWith(color: c.textSecondary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
