import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/app_error.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../application/issue_providers.dart';
import '../application/timeline_mapping.dart';
import '../../staff/flags/flag_content_sheet.dart';
import '../data/issue_models.dart';
import 'ccrs_closed.dart';
import 'common.dart';
import 'issue_status_actions.dart';
import 'motion/animated_status_chip.dart';
import 'motion/animated_status_timeline.dart';

/// `/issues/:id` — the issue's status, actions and timeline (TASK-06). An
/// interim body until TASK-07's detail screen, which embeds [IssueLifecyclePanel].
class IssueLifecycleScreen extends ConsumerWidget {
  const IssueLifecycleScreen({super.key, required this.issueId});

  final String issueId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(issueLifecycleProvider(issueId));
    final gu = Localizations.localeOf(context).languageCode == 'gu';
    final title = async.value == null
        ? l10n.issueActionsDetailTitle
        : (gu ? async.value!.categoryNameGu : async.value!.categoryNameEn);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: switch (async) {
        AsyncValue(:final value?) => RefreshIndicator(
          onRefresh: () async {
            refreshIssue(ref, issueId);
            await ref.read(issueLifecycleProvider(issueId).future);
          },
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.gutter),
            children: [IssueLifecyclePanel(issue: value)],
          ),
        ),
        AsyncValue(:final error?) => ErrorState(
          message: error is AppError
              ? lifecycleErrorMessage(l10n, error)
              : l10n.commonRetry,
          onRetry: () => refreshIssue(ref, issueId),
        ),
        _ => const SkeletonList(count: 4),
      },
    );
  }
}

/// Status chip, overdue tag, CCRS banner, citizen actions (verify, escalate,
/// AMC closed it), staff actions and the animated timeline. Rebuilt with a
/// new [issue] after a refresh, the chip and timeline animate the change.
class IssueLifecyclePanel extends ConsumerWidget {
  const IssueLifecyclePanel({super.key, required this.issue});

  final IssueLifecycle issue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final events = ref.watch(issueEventsProvider(issue.id));
    final a = issue.actions;
    final deadline = issue.ccrsReopenDeadline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.s8,
          runSpacing: AppSpacing.s8,
          children: [
            AnimatedStatusChip(
              status: issue.status,
              fixedUnverified: issue.fixedUnverified,
            ),
            if (issue.isOverdue) const OverdueTag(),
          ],
        ),
        const SizedBox(height: AppSpacing.s16),
        if (deadline != null) ...[
          CcrsClosedBanner(
            issueId: issue.id,
            deadline: deadline,
            canVerify: a.verify,
          ),
          const SizedBox(height: AppSpacing.s16),
        ],
        if (a.verify) ...[
          PrimaryButton(
            key: const Key('lifecycle.verify'),
            label: l10n.issueActionsVerifyCta,
            onPressed: () => context.push('/issues/${issue.id}/verify'),
          ),
          const SizedBox(height: AppSpacing.s8),
        ],
        if (a.escalate) ...[
          SecondaryButton(
            key: const Key('lifecycle.escalate'),
            label: l10n.issueActionsEscalateCta,
            onPressed: () => context.push('/issues/${issue.id}/escalate'),
          ),
          const SizedBox(height: AppSpacing.s8),
        ],
        if (a.ccrsClosed) ...[
          TertiaryButton(
            key: const Key('lifecycle.ccrsClosed'),
            label: l10n.issueActionsCcrsQuestion,
            onPressed: () => showCcrsClosedSheet(context, issue.id),
          ),
          const SizedBox(height: AppSpacing.s8),
        ],
        IssueStatusActions(issue: issue),
        const SizedBox(height: AppSpacing.s16),
        Text(l10n.issueActionsTimelineTitle, style: text.titleMedium),
        const SizedBox(height: AppSpacing.s12),
        switch (events) {
          AsyncValue(:final value?) => AnimatedStatusTimeline(
            rows: timelineRows(l10n, value, localeName: locale),
            onFlag: (eventId) => showFlagContentSheet(
              context,
              ref,
              issueId: issue.id,
              eventId: eventId,
            ),
            photo: (context, url) => SizedBox(
              width: 160,
              child: IssuePhoto(
                url: url,
                label: l10n.issueActionsTimelineAfterPhoto,
              ),
            ),
          ),
          AsyncValue(:final error?) => ErrorState(
            message: error is AppError
                ? lifecycleErrorMessage(l10n, error)
                : l10n.commonRetry,
            onRetry: () => ref.invalidate(issueEventsProvider(issue.id)),
          ),
          _ => const SkeletonList(count: 3),
        },
      ],
    );
  }
}
