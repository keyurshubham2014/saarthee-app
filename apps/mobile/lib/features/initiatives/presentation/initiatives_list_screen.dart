import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/app_error.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/settings/locale_controller.dart';
import '../../../core/theme/icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/wards/ward_providers.dart';
import '../../../core/widgets/widgets.dart';
import '../application/initiatives_providers.dart';
import 'widgets/initiative_card.dart';

/// `/initiatives` (TASK-12 §5.4): "My ward" (ward + city-wide) or "All city".
class InitiativesListScreen extends ConsumerStatefulWidget {
  const InitiativesListScreen({super.key});

  @override
  ConsumerState<InitiativesListScreen> createState() =>
      _InitiativesListScreenState();
}

class _InitiativesListScreenState extends ConsumerState<InitiativesListScreen> {
  bool _cityWide = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    final ward = ref.watch(homeWardProvider);
    final city = _cityWide || ward == null;
    final scope = city ? null : ward.id;
    final async = ref.watch(initiativesListProvider(scope));

    Widget body() => async.when(
      loading: () => const SkeletonList(),
      error: (e, _) => AppError.from(e).isOffline
          ? OfflineState(
              onRetry: () => ref.invalidate(initiativesListProvider(scope)),
            )
          : ErrorState(
              message: l10n.initiativesLoadError,
              onRetry: () => ref.invalidate(initiativesListProvider(scope)),
            ),
      data: (res) => RefreshIndicator(
        onRefresh: () => ref.refresh(initiativesListProvider(scope).future),
        child: ListView(
          key: const Key('initiatives.list'),
          padding: const EdgeInsets.only(bottom: AppSpacing.s24),
          children: [
            if (res.fromCache)
              NoticeBanner(
                kind: NoticeKind.offline,
                message: l10n.servicesOfflineCached,
              ),
            if (res.value.isEmpty)
              EmptyState(
                key: const Key('initiatives.empty'),
                icon: SaartheeIcons.event,
                message: city
                    ? l10n.initiativesEmptyCity
                    : l10n.initiativesEmptyWard,
                actionLabel: city ? null : l10n.initiativesSeeAllCity,
                onAction: city ? null : () => setState(() => _cityWide = true),
              )
            else
              for (final i in res.value)
                InitiativeCard(
                  initiative: i,
                  lang: lang,
                  onTap: () => context.push('/initiatives/${i.id}'),
                ),
          ],
        ),
      ),
    );

    return Scaffold(
      appBar: SaartheeAppBar(title: l10n.initiativesTitle),
      body: Column(
        children: [
          if (ward != null)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.gutter),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<bool>(
                  key: const Key('initiatives.scope'),
                  segments: [
                    ButtonSegment(
                      value: false,
                      label: Text(l10n.initiativesMyWard),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text(l10n.initiativesAllCity),
                    ),
                  ],
                  selected: {city},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) =>
                      setState(() => _cityWide = s.first),
                ),
              ),
            ),
          Expanded(child: body()),
        ],
      ),
    );
  }
}
