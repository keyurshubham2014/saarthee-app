import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/config/app_config.dart';
import '../../../core/format/issue_ref.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/motion/motion_widgets.dart';
import '../../../core/theme/icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../application/amc_handoff.dart';
import '../application/report_providers.dart';
import 'motion/success_hero.dart';

/// `/report/done` (TASK-05 §5.4): full-screen success (no step header), then
/// the optional "File with AMC too" hand-off.
class ReportDoneScreen extends ConsumerWidget {
  const ReportDoneScreen({super.key});

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    HandoffTarget t,
    String name,
  ) async {
    final l10n = AppLocalizations.of(context);
    final ok = await ref.read(amcHandoffProvider).open(t);
    if (!ok && context.mounted) {
      showSaartheeToast(
        context,
        l10n.reportHandoffFailed(name),
        kind: ToastKind.error,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final text = Theme.of(context).textTheme;
    final issue = ref.watch(lastSubmissionProvider);
    if (issue == null) {
      return Scaffold(
        body: EmptyState(
          message: l10n.errorNotFound,
          actionLabel: l10n.commonGoHome,
          onAction: () => context.go('/'),
        ),
      );
    }
    final ref0 = issueRef(issue.id);
    final amc = issue.primaryAmc;
    final other = issue.categorySlug == 'other' || amc == null;
    final category = categoryLabel(l10n, issue.categorySlug);
    final ward = (lang == 'gu' ? issue.wardNameGu : issue.wardNameEn) ?? '';
    final date = DateFormat.yMMMd(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(DateTime.now());
    final copyText = l10n.reportHandoffCopyText(
      category,
      issue.lat.toStringAsFixed(6),
      issue.lng.toStringAsFixed(6),
      ward,
      date,
    );
    return Scaffold(
      body: SafeArea(
        child: ListView(
          key: const Key('report.done'),
          padding: const EdgeInsets.all(AppSpacing.gutter),
          children: [
            const SizedBox(height: AppSpacing.s32),
            Semantics(
              liveRegion: true,
              label: l10n.reportDoneAnnounce(ref0),
              child: ExcludeSemantics(
                child: ReportSuccessHero(
                  checkLabel: l10n.reportDoneTitle,
                  issueNumber: Text(
                    l10n.reportDoneIssueNumber(ref0),
                    key: const Key('report.done.issueNumber'),
                    textAlign: TextAlign.center,
                    style: text.titleMedium,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
            StaggeredColumn(
              children: [
                Text(
                  l10n.reportDoneTitle,
                  textAlign: TextAlign.center,
                  style: text.displaySmall,
                ),
                const SizedBox(height: AppSpacing.s8),
                Text(
                  issue.hidden ? l10n.reportDoneSensitive : l10n.reportDoneBody,
                  textAlign: TextAlign.center,
                  style: text.bodyLarge,
                ),
                const SizedBox(height: AppSpacing.s24),
                Text(l10n.reportHandoffTitle, style: text.titleMedium),
                const SizedBox(height: AppSpacing.s8),
                Text(
                  other
                      ? l10n.reportHandoffOther
                      : l10n.reportHandoffCategory(
                          amc.dept(lang),
                          amc.problem(lang),
                        ),
                  key: const Key('report.done.amcType'),
                  style: text.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.s12),
                SecondaryButton(
                  label: l10n.reportHandoffWeb,
                  icon: SaartheeIcons.share,
                  onPressed: () => _open(
                    context,
                    ref,
                    HandoffTarget.web,
                    l10n.reportHandoffWeb,
                  ),
                ),
                const SizedBox(height: AppSpacing.s8),
                SecondaryButton(
                  label: l10n.reportHandoffWhatsapp,
                  icon: SaartheeIcons.chat,
                  onPressed: () => _open(
                    context,
                    ref,
                    HandoffTarget.whatsapp,
                    l10n.reportHandoffWhatsapp,
                  ),
                ),
                const SizedBox(height: AppSpacing.s8),
                SecondaryButton(
                  label: l10n.reportHandoffCall(AppConfig.amcHelpline),
                  icon: SaartheeIcons.phone,
                  onPressed: () => _open(
                    context,
                    ref,
                    HandoffTarget.phone,
                    l10n.reportHandoffCall(AppConfig.amcHelpline),
                  ),
                ),
                const SizedBox(height: AppSpacing.s8),
                SecondaryButton(
                  label: l10n.reportHandoffCopy,
                  icon: SaartheeIcons.copy,
                  onPressed: () async {
                    await ref.read(amcHandoffProvider).recordConsentOnce();
                    await Clipboard.setData(ClipboardData(text: copyText));
                    if (context.mounted) {
                      showSaartheeToast(context, l10n.reportHandoffCopied);
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.s16),
                const IndependenceNotice(),
                TertiaryButton(
                  label: l10n.reportHandoffLinkLater,
                  onPressed: () =>
                      context.push('/issues/${issue.id}/link-ccrs'),
                ),
                const SizedBox(height: AppSpacing.s16),
                PrimaryButton(
                  key: const Key('report.done.done'),
                  label: l10n.reportDoneDone,
                  onPressed: () => context.go('/'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
