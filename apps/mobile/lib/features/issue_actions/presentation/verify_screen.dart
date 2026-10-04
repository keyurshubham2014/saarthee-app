import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/app_error.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../application/issue_providers.dart';
import '../data/issue_models.dart';
import 'common.dart';

/// `/issues/:id/verify` — step 1 of 2 (TASK-06 §5.4, DS §8): "Is it fixed?"
/// with before/after photos side by side; the answers only navigate (the
/// network work happens on step 2's Send).
class VerifyScreen extends ConsumerWidget {
  const VerifyScreen({super.key, required this.issueId});

  final String issueId;

  static bool canCheck(IssueLifecycle i, DateTime now) {
    final closes = i.verifyWindowClosesAt;
    return closes != null && !now.isAfter(closes);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(issueLifecycleProvider(issueId));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.issueActionsVerifyTitle)),
      body: async.when(
        loading: () => const SkeletonList(count: 3),
        error: (e, _) => ErrorState(
          message: e is AppError
              ? lifecycleErrorMessage(l10n, e)
              : l10n.commonRetry,
          onRetry: () => ref.invalidate(issueLifecycleProvider(issueId)),
        ),
        data: (issue) => _Body(issue: issue),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.issue});
  final IssueLifecycle issue;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final open = VerifyScreen.canCheck(issue, DateTime.now());
    void go(String answer) =>
        context.push('/issues/${issue.id}/verify/photo?answer=$answer');
    return PinnedBottomLayout(
      top: const Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.s8,
          AppSpacing.gutter,
          0,
        ),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: VerifyStepLabel(step: 1),
        ),
      ),
      bottom: [
        if (open && !issue.answeredToday) ...[
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              key: const Key('verify.yes'),
              label: l10n.issueActionsVerifyYes,
              onPressed: () => go('fixed'),
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          SizedBox(
            width: double.infinity,
            child: SecondaryButton(
              key: const Key('verify.no'),
              label: l10n.issueActionsVerifyNo,
              onPressed: () => go('not_fixed'),
            ),
          ),
        ],
      ],
      children: [
        Text(l10n.issueActionsVerifyTitle, style: text.headlineSmall),
        const SizedBox(height: AppSpacing.s16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Labeled(
                label: l10n.issueActionsVerifyBefore,
                url: issue.reportPhotoUrl,
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: _Labeled(
                label: l10n.issueActionsVerifyAfter,
                url: issue.afterPhotoUrl,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s24),
        if (!open)
          NoticeBanner(
            key: const Key('verify.closed'),
            kind: NoticeKind.info,
            message: l10n.issueActionsVerifyClosed,
            rounded: true,
          )
        else if (issue.answeredToday)
          NoticeBanner(
            key: const Key('verify.already'),
            kind: NoticeKind.info,
            message: l10n.issueActionsVerifyAlready,
            rounded: true,
          ),
      ],
    );
  }
}

class _Labeled extends StatelessWidget {
  const _Labeled({required this.label, required this.url});
  final String label;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppSpacing.s4),
        IssuePhoto(
          url: url,
          label: url == null ? l10n.issueActionsVerifyNoPhoto : label,
        ),
      ],
    );
  }
}
