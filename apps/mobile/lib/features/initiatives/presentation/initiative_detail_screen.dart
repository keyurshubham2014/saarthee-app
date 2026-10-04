import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/app_error.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/settings/locale_controller.dart';
import '../../../core/theme/icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../../services/application/external_links.dart';
import '../application/initiatives_providers.dart';
import '../data/initiative_models.dart';
import 'widgets/initiative_card.dart';
import 'widgets/rsvp_panel.dart';

/// `/initiatives/:id` (TASK-12 §5.4): type, organiser + source, description,
/// when, where ("Open in maps"), going count and the RSVP morph.
class InitiativeDetailScreen extends ConsumerWidget {
  const InitiativeDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    final async = ref.watch(initiativeDetailProvider(id));
    return Scaffold(
      appBar: SaartheeAppBar(
        title: async.value?.title(lang) ?? l10n.initiativesTitle,
      ),
      body: async.when(
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
        loading: () => const SkeletonList(count: 4),
        error: (e, _) {
          final err = AppError.from(e);
          if (err.statusCode == 404 || err.code == 'NOT_FOUND') {
            return EmptyState(
              key: const Key('initiative.notFound'),
              message: l10n.initiativesNotFound,
            );
          }
          if (err.isOffline) {
            return OfflineState(
              onRetry: () => ref.invalidate(initiativeDetailProvider(id)),
            );
          }
          return ErrorState(
            message: l10n.initiativesLoadError,
            onRetry: () => ref.invalidate(initiativeDetailProvider(id)),
          );
        },
        data: (i) => _Body(initiative: i, lang: lang),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.initiative, required this.lang});

  final Initiative initiative;
  final String lang;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    final text = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final i = initiative;
    final launch = ref.read(externalLauncherProvider);

    Widget fact(IconData icon, String label, String value, {Widget? action}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.s12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: c.textSecondary),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: text.labelMedium?.copyWith(color: c.textSecondary),
                    ),
                    Text(value, style: text.bodyLarge),
                    ?action,
                  ],
                ),
              ),
            ],
          ),
        );

    return ListView(
      key: const Key('initiative.detail'),
      padding: const EdgeInsets.all(AppSpacing.gutter),
      children: [
        if (i.isCancelled) ...[
          Container(
            key: const Key('initiative.cancelled'),
            padding: const EdgeInsets.all(AppSpacing.s12),
            decoration: BoxDecoration(
              color: c.errorTint,
              borderRadius: AppRadii.cardRadius,
            ),
            child: Row(
              children: [
                Icon(SaartheeIcons.cancel, color: c.error),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Text(
                    l10n.initiativesCancelledBanner,
                    style: text.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
        ],
        Row(
          children: [
            Icon(initiativeTypeIcon(i.type), color: c.primary),
            const SizedBox(width: AppSpacing.s8),
            Text(
              initiativeTypeLabel(l10n, i.type),
              style: text.labelLarge?.copyWith(color: c.primaryDark),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s8),
        Text(i.title(lang), style: text.headlineSmall),
        const SizedBox(height: AppSpacing.s4),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.s8,
          children: [
            Text(
              l10n.initiativesBy(i.organiserName),
              style: text.bodyMedium?.copyWith(color: c.textSecondary),
            ),
            if (i.sourceUrl != null)
              TertiaryButton(
                key: const Key('initiative.source'),
                label: l10n.initiativesSource,
                icon: SaartheeIcons.openInNew,
                onPressed: () => launch(
                  Uri.parse(i.sourceUrl!),
                  LaunchMode.externalApplication,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.s16),
        Text(i.description(lang), style: text.bodyLarge),
        const SizedBox(height: AppSpacing.s16),
        fact(
          SaartheeIcons.schedule,
          l10n.initiativesWhen,
          initiativeWhen(l10n, i, locale),
        ),
        fact(
          SaartheeIcons.location,
          l10n.initiativesWhere,
          i.place(lang),
          action: i.lat == null || i.lng == null
              ? null
              : Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TertiaryButton(
                    key: const Key('initiative.maps'),
                    label: l10n.initiativesOpenInMaps,
                    onPressed: () => launch(
                      Uri.parse('geo:${i.lat},${i.lng}?q=${i.lat},${i.lng}'),
                      LaunchMode.externalApplication,
                    ),
                  ),
                ),
        ),
        const SizedBox(height: AppSpacing.s8),
        RsvpPanel(initiative: i),
        const SizedBox(height: AppSpacing.s24),
      ],
    );
  }
}
