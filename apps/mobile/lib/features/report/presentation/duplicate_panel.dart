import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/app_error.dart';
import '../../../core/config/app_config.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../application/report_draft_controller.dart';
import '../application/report_providers.dart';
import 'motion/duplicate_motion.dart';
import 'report_errors.dart';

/// "Already reported nearby" (TASK-05 §5.4, REQ-F-015): the nearest open
/// issue of the same category within 50 m, as a card that slides down from
/// under the map, with "Add me too" and "No, mine is different".
class DuplicatePanel extends ConsumerWidget {
  const DuplicatePanel({
    super.key,
    required this.slug,
    required this.pin,
    required this.dismissed,
  });

  final String slug;
  final PinKey pin;
  final List<String> dismissed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items =
        ref
            .watch(
              nearbyIssuesProvider((slug: slug, lat: pin.lat, lng: pin.lng)),
            )
            .value ??
        const <NearbyIssue>[];
    final open = items.where((i) => !dismissed.contains(i.id)).toList();
    if (open.isEmpty) return const SizedBox.shrink();
    return DuplicateCardSlide(
      key: ValueKey('report.dup.${open.first.id}'),
      child: _DuplicateCard(issue: open.first),
    );
  }
}

class _DuplicateCard extends ConsumerWidget {
  const _DuplicateCard({required this.issue});

  final NearbyIssue issue;

  Future<bool> _meToo(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(reportActionsProvider).meToo(issue.id);
      return true;
    } on AppError catch (e) {
      if (context.mounted) {
        final l10n = AppLocalizations.of(context);
        showSaartheeToast(
          context,
          reportError(l10n, e).message,
          kind: ToastKind.error,
        );
      }
      return false;
    }
  }

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final router = GoRouter.of(context);
    // The card unmounts once the draft is gone: show the dialog from the root.
    final nav = Navigator.of(context, rootNavigator: true);
    ref.read(reportDraftProvider.notifier).discard();
    await showDialog<void>(
      context: nav.context,
      builder: (c) => AlertDialog(
        key: const Key('report.dup.confirmation'),
        title: Text(l10n.reportDupConfirmTitle),
        content: Text(l10n.reportDupConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(),
            child: Text(l10n.reportDoneDone),
          ),
        ],
      ),
    );
    router.go('/');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final c = SaartheeColors.of(context);
    final text = Theme.of(context).textTheme;
    final thumb = issue.thumbnailUrl;
    final ward = lang == 'gu' ? issue.wardNameGu : issue.wardNameEn;
    return Container(
      key: const Key('report.dup.card'),
      margin: const EdgeInsets.only(top: AppSpacing.s8),
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.reportDupTitle, style: text.titleSmall),
          const SizedBox(height: AppSpacing.s8),
          Row(
            children: [
              if (thumb != null)
                ClipRRect(
                  borderRadius: AppRadii.controlRadius,
                  child: Image.network(
                    Uri.parse(AppConfig.apiBaseUrl).resolve(thumb).toString(),
                    width: 64,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox(width: 64),
                  ),
                )
              else
                CategoryBadge(slug: issue.categorySlug),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      [
                        categoryLabel(l10n, issue.categorySlug),
                        ?ward,
                      ].join(' · '),
                      style: text.bodyLarge,
                    ),
                    Text(
                      l10n.reportDupMeta(issue.distanceM, issue.meTooCount),
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          MeTooButton(
            onPressed: () => _meToo(context, ref),
            onAdded: () => _confirm(context, ref),
          ),
          TertiaryButton(
            key: const Key('report.dup.different'),
            label: l10n.reportDupDifferent,
            onPressed: () => ref
                .read(reportDraftProvider.notifier)
                .dismissDuplicate(issue.id),
          ),
        ],
      ),
    );
  }
}
