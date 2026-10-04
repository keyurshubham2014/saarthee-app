import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/app_error.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/settings/locale_controller.dart';
import '../../../core/theme/icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../application/external_links.dart';
import '../application/services_providers.dart';
import '../data/service_models.dart';
import 'widgets/service_badges.dart';
import 'widgets/ward_office_card.dart';

/// `/services/:slug` (TASK-12 §5.4): summary, numbered steps, "Open on AMC
/// website" (external browser) with the independence caption, ward office
/// card, source line and the broken-link warning.
class ServiceDetailScreen extends ConsumerWidget {
  const ServiceDetailScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(serviceDetailProvider(slug));
    final lang = ref.watch(localeProvider).languageCode;
    return Scaffold(
      appBar: SaartheeAppBar(
        title: async.value?.summary.name(lang) ?? l10n.servicesTitle,
      ),
      body: async.when(
        loading: () => const SkeletonList(count: 4),
        error: (e, _) {
          final err = AppError.from(e);
          if (err.statusCode == 404 || err.code == 'NOT_FOUND') {
            return EmptyState(
              key: const Key('service.notFound'),
              message: l10n.servicesNotListed,
            );
          }
          if (err.isOffline) {
            return OfflineState(
              onRetry: () => ref.invalidate(serviceDetailProvider(slug)),
            );
          }
          return ErrorState(
            message: l10n.servicesLoadError,
            onRetry: () => ref.invalidate(serviceDetailProvider(slug)),
          );
        },
        data: (s) => _Body(service: s, lang: lang),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.service, required this.lang});

  final ServiceDetail service;
  final String lang;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    final text = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final steps = service.steps(lang);
    final checked = service.summary.linkOk == null
        ? null
        : service.lastCheckedAt;

    Future<void> open() async {
      final uri = Uri.tryParse(service.url);
      final ok =
          uri != null &&
          await ref.read(externalLauncherProvider)(
            uri,
            LaunchMode.externalApplication,
          );
      if (!ok && context.mounted) {
        showSaartheeToast(
          context,
          l10n.servicesLinkFailed,
          kind: ToastKind.error,
        );
      }
    }

    return ListView(
      key: const Key('service.detail'),
      padding: const EdgeInsets.all(AppSpacing.gutter),
      children: [
        if (service.summary.linkOk == false && checked != null) ...[
          Container(
            key: const Key('service.brokenLink'),
            padding: const EdgeInsets.all(AppSpacing.s12),
            decoration: BoxDecoration(
              color: c.warningTint,
              borderRadius: AppRadii.cardRadius,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(SaartheeIcons.warning, color: c.warning),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Text(
                    l10n.servicesBrokenLink(Formatters.date(checked, locale)),
                    style: text.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
        ],
        Text(service.departmentName(lang), style: text.labelLarge),
        const SizedBox(height: AppSpacing.s8),
        ServiceBadges(service: service.summary),
        const SizedBox(height: AppSpacing.s12),
        Text(service.summary.summary(lang), style: text.bodyLarge),
        const SizedBox(height: AppSpacing.s24),
        Semantics(
          header: true,
          child: Text(l10n.servicesHowTo, style: text.titleLarge),
        ),
        const SizedBox(height: AppSpacing.s12),
        for (var i = 0; i < steps.length; i++)
          Padding(
            key: Key('service.step.$i'),
            padding: const EdgeInsets.only(bottom: AppSpacing.s12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: AppSpacing.s14,
                  backgroundColor: c.primaryContainer,
                  child: Text(
                    '${i + 1}',
                    style: text.labelLarge?.copyWith(color: c.primaryDark),
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(child: Text(steps[i], style: text.bodyMedium)),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.s16),
        PrimaryButton(
          key: const Key('service.open'),
          label: l10n.servicesOpenOnAmc,
          icon: SaartheeIcons.openInNew,
          onPressed: open,
        ),
        const SizedBox(height: AppSpacing.s8),
        Text(
          l10n.servicesOpensCaption(service.host),
          key: const Key('service.caption'),
          style: text.bodySmall,
        ),
        if (service.summary.visitWardOffice) ...[
          const SizedBox(height: AppSpacing.s24),
          WardOfficeCard(office: service.wardOffice, lang: lang),
        ],
        const SizedBox(height: AppSpacing.s24),
        Text(
          checked == null
              ? l10n.servicesSourceOnly
              : l10n.servicesSourceLine(Formatters.date(checked, locale)),
          key: const Key('service.source'),
          style: text.bodySmall?.copyWith(color: c.textSecondary),
        ),
      ],
    );
  }
}
