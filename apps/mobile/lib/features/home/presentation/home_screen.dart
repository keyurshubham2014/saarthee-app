import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../report/application/report_draft_controller.dart';

/// `/` Home (02 §4.3).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsProvider);
    final offline = ref.watch(isOfflineProvider);
    final draft = ref.watch(reportDraftProvider);
    final hasDraft = draft != null;
    final myReports = ref.watch(myReportsProvider);

    return Scaffold(
      body: PinnedBottomLayout(
        top: offline ? const OfflineBanner() : null,
        children: [
          Text(
            l10n.appTitle,
            style: theme.textTheme.titleLarge?.copyWith(
              color: AppColors.indigo,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const IndependenceNotice(),
          if (settings.groupLabel != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.homeGroupLabel(settings.groupLabel!),
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          _ActionCard(
            key: const Key('home.record'),
            icon: hasDraft
                ? Icons.edit_note_rounded
                : Icons.add_a_photo_rounded,
            title: hasDraft ? l10n.homeContinueTitle : l10n.homeRecordTitle,
            body: hasDraft ? l10n.homeContinueBody : l10n.homeRecordBody,
            emphasis: true,
            onTap: () {
              if (hasDraft) {
                context.go(
                  ref.read(reportDraftProvider.notifier).resumeRoute(),
                );
              } else {
                context.go('/report/category');
              }
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          _ActionCard(
            key: const Key('home.followUp'),
            icon: Icons.fact_check_rounded,
            title: l10n.homeFollowUpTitle,
            body: l10n.homeFollowUpBody,
            onTap: () => context.go('/verify/enter-code'),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Semantics(
            header: true,
            child: Text(
              l10n.homeMyReportsTitle,
              style: theme.textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (myReports.isEmpty)
            Text(l10n.homeMyReportsEmpty, style: theme.textTheme.bodyMedium)
          else
            for (final r in myReports)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    const Icon(
                      Icons.description_outlined,
                      color: AppColors.inkMuted,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        l10n.homeMyReportsItem(
                          r.ccrsNumber,
                          r.categoryName,
                          Formatters.date(r.createdAt),
                        ),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: AppSpacing.xl),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('home.about'),
              onPressed: () => context.go('/about'),
              icon: const Icon(Icons.info_outline_rounded),
              label: Text(l10n.homeAboutLink),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
    this.emphasis = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = emphasis ? AppColors.white : AppColors.ink;
    return Semantics(
      button: true,
      child: Material(
        color: emphasis ? AppColors.indigo : AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.cardRadius,
          side: emphasis
              ? BorderSide.none
              : const BorderSide(color: AppColors.fieldBorder),
        ),
        child: InkWell(
          borderRadius: AppRadii.cardRadius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Row(
              children: [
                Icon(icon, size: 32, color: fg),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleLarge?.copyWith(color: fg),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        body,
                        style: theme.textTheme.bodyMedium?.copyWith(color: fg),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: fg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
