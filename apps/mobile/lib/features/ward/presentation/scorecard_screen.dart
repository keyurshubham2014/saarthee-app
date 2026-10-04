import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/app_error.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/scorecard/scorecard.dart';
import '../../../core/widgets/widgets.dart';
import '../application/ward_providers.dart';
import '../data/ward_api.dart';
import '../data/ward_models.dart';
import 'election_banner.dart';

/// `/ward/:id/scorecard` (TASK-09 §5.4, REQ-F-046): six stat tiles (numbers
/// count up and the two percentage bars grow on the first view in this
/// session only), a method note, sample-size and election-mode states.
class ScorecardScreen extends ConsumerWidget {
  const ScorecardScreen({super.key, required this.wardId});

  final String wardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(wardScorecardProvider(wardId));
    final number = ref
        .watch(wardRepresentativesProvider(wardId))
        .value
        ?.ward
        .number;
    void retry() => ref.invalidate(wardScorecardProvider(wardId));
    return Scaffold(
      appBar: SaartheeAppBar(
        title: number == null
            ? l10n.myWardScorecardRow
            : l10n.scorecardTitle(number),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(wardScorecardProvider(wardId).future),
        child: async.when(
          loading: () => const SkeletonList(count: 3, twoLine: false),
          error: (e, _) => ListView(
            children: [
              if (AppError.from(e).isOffline)
                OfflineState(onRetry: retry)
              else
                ErrorState(message: l10n.scorecardLoadError, onRetry: retry),
            ],
          ),
          data: (s) => s.hidden ? _Paused(card: s) : _Body(card: s),
        ),
      ),
    );
  }
}

class _Paused extends StatelessWidget {
  const _Paused({required this.card});

  final WardScorecard card;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      children: [
        ElectionBanner(status: ElectionStatus(active: true, until: card.until)),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          child: Text(
            l10n.scorecardPaused,
            key: const Key('scorecard.paused'),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.card});

  final WardScorecard card;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).languageCode;
    final key = 'scorecard:${card.wardId}';
    final updated = card.refreshedAt;
    final notEnough = l10n.scorecardNotEnough;
    final tiles = <Widget>[
      ScorecardStatTile(
        key: const Key('scorecard.ack'),
        value: card.medianDaysAck,
        decimals: 1,
        label: l10n.scorecardMedianAck,
        emptyText: notEnough,
        animateKey: '$key:ack',
      ),
      ScorecardStatTile(
        key: const Key('scorecard.fix'),
        value: card.medianDaysFix,
        decimals: 1,
        label: l10n.scorecardMedianFix,
        emptyText: notEnough,
        animateKey: '$key:fix',
      ),
      ScorecardStatTile(
        key: const Key('scorecard.verified'),
        value: card.verifiedPct,
        decimals: 0,
        suffix: '%',
        label: l10n.scorecardVerified,
        emptyText: notEnough,
        animateKey: '$key:verified',
        barFraction: (card.verifiedPct ?? 0) / 100,
      ),
      ScorecardStatTile(
        key: const Key('scorecard.reopened'),
        value: card.reopenPct,
        decimals: 0,
        suffix: '%',
        label: l10n.scorecardReopened,
        emptyText: notEnough,
        animateKey: '$key:reopened',
        barFraction: (card.reopenPct ?? 0) / 100,
      ),
      ScorecardStatTile(
        key: const Key('scorecard.backlog'),
        value: card.openBacklog.toDouble(),
        label: l10n.scorecardBacklog,
        animateKey: '$key:backlog',
      ),
      ScorecardStatTile(
        key: const Key('scorecard.per1000'),
        value: card.reportsPer1000,
        decimals: 1,
        label: l10n.scorecardPer1000,
        emptyText: l10n.scorecardNoPopulation,
        animateKey: '$key:per1000',
      ),
    ];
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      children: [
        Text(
          l10n.scorecardSubtitle(
            card.windowDays,
            updated == null
                ? '—'
                : DateFormat.jm(locale).format(Formatters.toIst(updated)),
          ),
          style: text.bodyMedium,
        ),
        Text(
          l10n.scorecardIssuesReported(card.windowDays, card.issuesReported),
          style: text.bodySmall,
        ),
        const SizedBox(height: AppSpacing.s16),
        // Two columns (one at large font sizes); rows size to content so
        // tiles never clip at 2.0× text.
        LayoutBuilder(
          builder: (context, box) {
            final scale = MediaQuery.textScalerOf(context).scale(1);
            final cols = box.maxWidth >= 300 && scale <= 1.3 ? 2 : 1;
            return Column(
              children: [
                for (var i = 0; i < tiles.length; i += cols)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.s12),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (
                            var j = 0;
                            j < cols && i + j < tiles.length;
                            j++
                          ) ...[
                            if (j > 0) const SizedBox(width: AppSpacing.s12),
                            Expanded(child: tiles[i + j]),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.s16),
        ExpansionTile(
          key: const Key('scorecard.method'),
          tilePadding: EdgeInsets.zero,
          title: Text(l10n.scorecardMethodTitle, style: text.titleMedium),
          children: [
            Text(
              l10n.scorecardMethodBody(
                card.populationSource ?? l10n.scorecardMethodNoSource,
              ),
              style: text.bodyMedium,
            ),
          ],
        ),
      ],
    );
  }
}
