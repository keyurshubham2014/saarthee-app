import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/settings/locale_controller.dart';
import '../../../../core/theme/icons.dart';
import '../../../../core/theme/tokens.dart';
import '../../application/services_providers.dart';

/// Home seasonal tip (TASK-12 §5.4, REQ-F-061): info-banner styling with
/// title, body, "Open" (→ linked service) and dismiss (remembered on this
/// device). Hidden when there is no tip, on error, or all are dismissed.
class ServiceTipCard extends ConsumerWidget {
  const ServiceTipCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tips = ref.watch(serviceTipsProvider).value ?? const [];
    final dismissed = ref.watch(dismissedTipsProvider);
    final visible = tips.where((t) => !dismissed.contains(t.id)).toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    final tip = visible.first;
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    final text = Theme.of(context).textTheme;
    final lang = ref.watch(localeProvider).languageCode;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.s16,
        AppSpacing.gutter,
        0,
      ),
      child: Semantics(
        container: true,
        child: Container(
          key: Key('home.tip.${tip.id}'),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s16,
            AppSpacing.s12,
            AppSpacing.s4,
            AppSpacing.s8,
          ),
          decoration: BoxDecoration(
            color: c.infoTint,
            borderRadius: AppRadii.cardRadius,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.s4),
                child: Icon(SaartheeIcons.info, color: c.info),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tip.title(lang), style: text.titleMedium),
                    const SizedBox(height: AppSpacing.s4),
                    Text(tip.body(lang), style: text.bodyMedium),
                    if (tip.serviceSlug != null)
                      TextButton(
                        key: const Key('home.tip.open'),
                        onPressed: () =>
                            context.push('/services/${tip.serviceSlug}'),
                        child: Text(l10n.servicesTipOpen),
                      ),
                  ],
                ),
              ),
              IconButton(
                key: const Key('home.tip.dismiss'),
                tooltip: l10n.servicesTipDismiss,
                icon: Icon(SaartheeIcons.close, color: c.textSecondary),
                onPressed: () =>
                    ref.read(dismissedTipsProvider.notifier).dismiss(tip.id),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
