import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/app_error.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/motion/staggered.dart';
import '../../../core/settings/locale_controller.dart';
import '../../../core/theme/icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../application/ward_providers.dart';
import '../data/ward_models.dart';
import 'election_banner.dart';
import 'rep_row.dart';

const int kCorporatorSeats = 4;

/// Representatives, ward office and scorecard link for one ward (TASK-09
/// §5.4), used by the My Ward tab and `/ward/:id`. Rows rise in with a 60 ms
/// stagger on the first load of a ward in this session only (DS §6).
class WardRepresentativesSection extends ConsumerWidget {
  const WardRepresentativesSection({super.key, required this.wardId});

  final String wardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(wardRepresentativesProvider(wardId));
    void retry() => ref.invalidate(wardRepresentativesProvider(wardId));
    return async.when(
      loading: () => const SkeletonList(count: 4),
      error: (e, _) => AppError.from(e).isOffline
          ? OfflineState(onRetry: retry)
          : ErrorState(message: l10n.myWardLoadError, onRetry: retry),
      data: (data) => _WardContent(data: data),
    );
  }
}

class _WardContent extends ConsumerWidget {
  const _WardContent({required this.data});

  final WardRepresentatives data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    final text = Theme.of(context).textTheme;
    final lang = ref.watch(localeProvider).languageCode;
    final ward = data.ward;

    Widget title(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.sectionTitleTop,
        AppSpacing.gutter,
        AppSpacing.s4,
      ),
      child: Semantics(header: true, child: Text(t, style: text.titleLarge)),
    );

    Widget row(RepSummary r) => WardRepRow(
      key: Key('ward.rep.${r.id}'),
      rep: r,
      lang: lang,
      onOpen: () => context.push('/representatives/${r.id}'),
      onMessage: r.canMessage
          ? () => context.push('/representatives/${r.id}/message')
          : null,
    );

    final children = <Widget>[
      if (data.election.active) ElectionBanner(status: data.election),
      if (data.fromCache)
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.s8,
            AppSpacing.gutter,
            0,
          ),
          child: NoticeBanner(
            kind: NoticeKind.offline,
            rounded: true,
            message: l10n.myWardCachedNote,
          ),
        ),
      if (data.isEmpty)
        Padding(
          key: const Key('ward.noReps'),
          padding: const EdgeInsets.all(AppSpacing.gutter),
          child: Text(l10n.myWardNoReps, style: text.bodyMedium),
        )
      else ...[
        title(l10n.myWardCorporators),
        ...data.corporators.map(row),
        for (var i = data.corporators.length; i < kCorporatorSeats; i++)
          PendingSeatRow(key: Key('ward.pendingSeat.$i')),
        if (data.mlas.isNotEmpty) title(l10n.myWardMlas),
        if (ward.acCount > 1)
          Padding(
            key: const Key('ward.multiAc'),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
            child: Text(
              l10n.myWardMultiAc(ward.acCount),
              style: text.bodySmall,
            ),
          ),
        ...data.mlas.map(row),
        if (data.mps.isNotEmpty) title(l10n.myWardMps),
        ...data.mps.map(row),
      ],
      title(l10n.myWardOffice),
      _OfficeCard(ward: ward, lang: lang),
      const SizedBox(height: AppSpacing.s8),
      ListRow(
        key: const Key('ward.scorecardRow'),
        leading: Icon(SaartheeIcons.insights, color: c.primary),
        title: l10n.myWardScorecardRow,
        subtitle: l10n.myWardScorecardRowHint,
        onTap: () => context.push('/ward/${ward.id}/scorecard'),
      ),
    ];
    return StaggeredColumn(
      key: Key('ward.section.${ward.id}'),
      seenOnceKey: 'myWard:${ward.id}',
      children: children,
    );
  }
}

class _OfficeCard extends ConsumerWidget {
  const _OfficeCard({required this.ward, required this.lang});

  final WardInfo ward;
  final String lang;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    final text = Theme.of(context).textTheme;
    final address = ward.officeAddress(lang);
    final phone = ward.officePhone;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      child: Container(
        key: const Key('ward.office'),
        padding: const EdgeInsets.all(AppSpacing.s16),
        decoration: AppElevation.cardDecoration(c),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(address ?? l10n.myWardOfficeNone, style: text.bodyMedium),
            if (phone != null) ...[
              const SizedBox(height: AppSpacing.s8),
              Row(
                children: [
                  Icon(SaartheeIcons.phone, color: c.textSecondary),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(child: Text(phone, style: text.bodyMedium)),
                  TextButton(
                    key: const Key('ward.office.call'),
                    onPressed: () => ref.read(wardLauncherProvider)(
                      Uri(scheme: 'tel', path: phone),
                    ),
                    child: Text(l10n.myWardOfficeCall),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
