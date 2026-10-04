import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/app_error.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/settings/locale_controller.dart';
import '../../../core/theme/icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/alerts/alert_widgets.dart';
import '../../../core/widgets/widgets.dart';
import '../application/alerts_providers.dart';
import '../data/alert_models.dart';
import 'alert_labels.dart';

/// `/alerts/:id` (REQ-F-038, REQ-S-011): severity banner, what, where, when,
/// source line + independence line, "Turn off alerts like this".
class AlertDetailScreen extends ConsumerWidget {
  const AlertDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final alert = ref.watch(alertDetailProvider(id));
    return Scaffold(
      appBar: SaartheeAppBar(title: l10n.alertsTitle),
      body: alert.when(
        loading: () => const SkeletonList(count: 3),
        error: (e, _) {
          final err = AppError.from(e);
          if (err.statusCode == 404 || err.code == 'NOT_FOUND') {
            return EmptyState(
              message: l10n.alertsDetailNotAvailable,
              icon: SaartheeIcons.searchOff,
            );
          }
          return ErrorState(
            message: l10n.alertsLoadError,
            onRetry: () => ref.invalidate(alertDetailProvider(id)),
          );
        },
        data: (a) => _Body(alert: a),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.alert});

  final Alert alert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    final text = Theme.of(context).textTheme;
    final c = SaartheeColors.of(context);
    final ended = !alert.isActive;
    final notice = switch (alert.status) {
      AlertStatus.retracted => l10n.alertsDetailCancelled(
        alert.retractionReason ?? '',
      ),
      AlertStatus.expired => l10n.alertsDetailEnded,
      AlertStatus.published => null,
    };
    Widget section(String title, String value) => Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: text.titleSmall?.copyWith(color: c.textSecondary)),
          const SizedBox(height: AppSpacing.s4),
          Text(value, style: text.bodyLarge),
        ],
      ),
    );
    final where = alert.scope == 'wards' && alert.wards.length > 1
        ? alert.wards
              .map(
                (w) => l10n.alertsAreaWard(
                  w.number,
                  lang == 'gu' ? w.nameGu : w.nameEn,
                ),
              )
              .join(', ')
        : alertAreaLabel(l10n, lang, alert);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      children: [
        SeverityBanner(severity: alert.severity, message: notice, ended: ended),
        if (alert.supersededById != null)
          TextButton.icon(
            key: const ValueKey('alertNewer'),
            onPressed: () => context.push('/alerts/${alert.supersededById}'),
            icon: const Icon(SaartheeIcons.forward),
            label: Text(l10n.alertsDetailNewer),
          ),
        const SizedBox(height: AppSpacing.s16),
        Semantics(
          header: true,
          child: Text(alert.title(lang), style: text.titleLarge),
        ),
        const SizedBox(height: AppSpacing.s8),
        Text(alert.body(lang), style: text.bodyLarge),
        section(l10n.alertsDetailWhere, where),
        section(l10n.alertsDetailWhen, alertValidityLabel(l10n, lang, alert)),
        const SizedBox(height: AppSpacing.s16),
        SourceLine(
          source: alert.sourceName,
          onOpen: () => launchUrl(
            Uri.parse(alert.sourceUrl),
            mode: LaunchMode.externalApplication,
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            key: const ValueKey('alertTurnOff'),
            onPressed: () => context.push(
              Uri(
                path: '/alerts/settings',
                queryParameters: {'type': alert.type.api},
              ).toString(),
            ),
            child: Text(l10n.alertsTurnOff),
          ),
        ),
        const IndependenceFooter(),
      ],
    );
  }
}
