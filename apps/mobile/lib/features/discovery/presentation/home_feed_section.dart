import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/motion/staggered.dart';
import '../../../core/theme/icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/wards/ward.dart';
import '../../../core/widgets/widgets.dart';
import '../../alerts/application/alerts_providers.dart';
import '../../alerts/data/alert_models.dart';
import '../../alerts/presentation/alert_labels.dart';
import '../application/discovery_providers.dart';
import 'widgets/issue_card_tile.dart';

/// Session key: the Home feed stagger plays once per app process (DS §6).
const String homeFeedIntroKey = 'home.feed';

/// Home below the header (TASK-07, replaces P-01/P-02): the ward's active
/// alerts (TASK-08), stat tiles, "Issues near you" (≤ 10) and "See all".
/// The first successful render staggers in; tab returns and refreshes don't.
class HomeFeedSection extends ConsumerWidget {
  const HomeFeedSection({
    super.key,
    required this.ward,
    required this.onReport,
    required this.onAlerts,
  });

  final Ward ward;
  final VoidCallback onReport;
  final VoidCallback onAlerts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final feed = ref.watch(homeFeedProvider(ward.id));
    final alerts =
        ref.watch(alertsListProvider(true)).value?.items ?? const <Alert>[];
    return switch (feed) {
      AsyncValue(:final value?) => StaggeredColumn(
        key: const Key('home.feed'),
        seenOnceKey: homeFeedIntroKey,
        children: [
          if (value.cachedAt != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.s12,
                AppSpacing.gutter,
                0,
              ),
              child: NoticeBanner(
                key: const Key('home.offlineNote'),
                kind: NoticeKind.offline,
                rounded: true,
                message: l10n.discoveryOfflineSince(
                  DateFormat.Hm(lang).format(value.cachedAt!),
                ),
              ),
            ),
          if (alerts.isNotEmpty)
            _AlertsStrip(alerts: alerts.take(3).toList(), onAll: onAlerts),
          if (value.nearby.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.s16,
                AppSpacing.gutter,
                0,
              ),
              child: Row(
                key: const Key('home.stats'),
                children: [
                  Expanded(
                    child: StatTile(
                      value: value.openCount,
                      label: l10n.discoveryStatOpen,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: StatTile(
                      value: value.overdueCount,
                      label: l10n.discoveryStatOverdue,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: StatTile(
                      value: value.affected,
                      label: l10n.discoveryStatAffected,
                    ),
                  ),
                ],
              ),
            ),
          _SectionTitle(l10n.homeSectionNearby),
          if (value.nearby.isEmpty)
            EmptyState(
              key: const Key('home.nearbyEmpty'),
              icon: SaartheeIcons.taskAlt,
              message: l10n.discoveryNoIssuesInWard(ward.name(lang)),
              actionLabel: l10n.homeReportCardTitle,
              onAction: onReport,
            )
          else ...[
            for (final i in value.nearby)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  0,
                  AppSpacing.gutter,
                  AppSpacing.cardGap,
                ),
                child: IssueCardTile(issue: i),
              ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.gutter,
                ),
                child: TertiaryButton(
                  key: const Key('home.seeAll'),
                  label: l10n.discoverySeeAll,
                  onPressed: () => context.push('/issues?ward=${ward.id}'),
                ),
              ),
            ),
          ],
        ],
      ),
      AsyncValue(hasError: true) => ErrorState(
        key: const Key('home.feedError'),
        message: l10n.discoveryFeedError,
        onRetry: () => ref.invalidate(homeFeedProvider(ward.id)),
      ),
      _ => const SkeletonList(key: Key('home.feedLoading'), count: 3),
    };
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.gutter,
      AppSpacing.sectionTitleTop,
      AppSpacing.gutter,
      AppSpacing.sectionTitleBottom,
    ),
    child: Semantics(
      header: true,
      child: Text(title, style: Theme.of(context).textTheme.titleLarge),
    ),
  );
}

/// Active alerts of my wards (TASK-08 `GET /alerts`), hidden when empty.
class _AlertsStrip extends StatelessWidget {
  const _AlertsStrip({required this.alerts, required this.onAll});

  final List<Alert> alerts;
  final VoidCallback onAll;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    return Column(
      key: const Key('home.alerts'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(l10n.homeSectionAlerts),
        for (final a in alerts)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              0,
              AppSpacing.gutter,
              AppSpacing.cardGap,
            ),
            child: Semantics(
              label: alertSemanticsLabel(l10n, lang, a),
              button: true,
              excludeSemantics: true,
              child: AlertCard(
                key: ValueKey('home.alert.${a.id}'),
                severity: a.severity,
                title: a.title(lang),
                area: alertAreaLabel(l10n, lang, a),
                validity: alertValidityLabel(l10n, lang, a),
                source: a.sourceName,
                onTap: () => context.push('/alerts/${a.id}'),
              ),
            ),
          ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
            child: TertiaryButton(
              key: const Key('home.allAlerts'),
              label: l10n.discoveryAllAlerts,
              onPressed: onAll,
            ),
          ),
        ),
      ],
    );
  }
}
