import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/api/app_error.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/motion/staggered.dart';
import '../../../core/theme/icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../../issue_actions/application/issue_providers.dart';
import '../../issue_actions/presentation/issue_lifecycle_screen.dart';
import '../application/discovery_providers.dart';
import '../application/social_controller.dart';
import '../data/discovery_models.dart';
import 'share_issue.dart';
import 'widgets/issue_card_tile.dart';
import 'widgets/social_buttons.dart';

/// `/issues/:id` (TASK-07, replaces TASK-06's interim screen): before/after
/// photos, title, meta, "Reported by a resident of (ward)", Saarthee target,
/// Me too / Follow / Share, reporter's CCRS link, and TASK-06's
/// [IssueLifecyclePanel] (status, verify, escalate, staff actions,
/// timeline). Photo and title arrive by Hero from the card; the rest rises
/// with `stagger`.
class IssueDetailScreen extends ConsumerWidget {
  const IssueDetailScreen({super.key, required this.issueId});

  final String issueId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(issueDetailProvider(issueId));
    ref.listen(issueDetailProvider(issueId), (_, next) {
      final d = next.value;
      if (d != null) {
        ref.read(socialProvider(issueId).notifier).seed(d.issue);
      }
    });
    final loaded = async.value;
    if (loaded != null && !ref.read(socialProvider(issueId)).seeded) {
      Future.microtask(
        () => ref.read(socialProvider(issueId).notifier).seed(loaded.issue),
      );
    }
    return Scaffold(
      appBar: SaartheeAppBar(
        title: loaded == null
            ? l10n.issueActionsDetailTitle
            : loaded.issue.categoryName(
                Localizations.localeOf(context).languageCode,
              ),
      ),
      body: switch (async) {
        AsyncValue(:final value?) => RefreshIndicator(
          onRefresh: () async {
            refreshIssue(ref, issueId);
            ref.invalidate(issueDetailProvider(issueId));
            await ref.read(issueDetailProvider(issueId).future);
          },
          child: _Body(detail: value),
        ),
        AsyncValue(:final error?) =>
          error is AppError && error.code == 'NOT_FOUND'
              ? EmptyState(
                  key: const Key('detail.notFound'),
                  icon: SaartheeIcons.searchOff,
                  message: l10n.discoveryNotAvailable,
                )
              : ErrorState(
                  message: l10n.discoveryLoadError,
                  onRetry: () => ref.invalidate(issueDetailProvider(issueId)),
                ),
        _ => const SkeletonList(count: 4),
      },
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.detail});

  final LoadedDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final lang = Localizations.localeOf(context).languageCode;
    final d = detail.issue;
    final offline = detail.fromCache;
    final life = ref.watch(issueLifecycleProvider(d.id));
    final ward = d.wardName(lang);
    final pad = const EdgeInsets.symmetric(horizontal: AppSpacing.gutter);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: AppSpacing.s40),
      children: [
        if (d.mergedIntoId != null)
          _Banner(
            key: const Key('detail.merged'),
            message: l10n.discoveryMergedBanner,
            action: l10n.discoveryOpenIt,
            onAction: () =>
                context.pushReplacement('/issues/${d.mergedIntoId}'),
          ),
        if (d.status == IssueStatus.rejected && d.rejectionReason != null)
          _Banner(
            key: const Key('detail.rejected'),
            message: l10n.discoveryRejected(d.rejectionReason!),
          ),
        if (offline)
          NoticeBanner(
            key: const Key('detail.offline'),
            kind: NoticeKind.offline,
            message: l10n.discoveryOfflineActions,
          ),
        _Photos(detail: d),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.s16,
            AppSpacing.gutter,
            AppSpacing.s4,
          ),
          child: Hero(
            tag: 'issue-title-${d.id}',
            child: Material(
              type: MaterialType.transparency,
              child: Text(
                d.title,
                key: const Key('detail.title'),
                style: text.titleLarge,
              ),
            ),
          ),
        ),
        StaggeredColumn(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: pad,
              child: Text(
                issueSubline(d.title, [
                  d.categoryName(lang),
                  ward,
                ], ageLabel(l10n, d.createdAt)),
                key: const Key('detail.meta'),
                style: text.bodySmall,
              ),
            ),
            Padding(
              padding: pad,
              child: Text(
                l10n.discoveryReportedBy(ward),
                key: const Key('detail.reportedBy'),
                style: text.bodyMedium,
              ),
            ),
            if (d.isOpen)
              Padding(
                padding: pad.add(const EdgeInsets.only(top: AppSpacing.s8)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.discoveryTarget(
                        DateFormat.MMMd(lang).format(d.slaDueAt),
                      ),
                      style: text.bodyMedium,
                    ),
                    Text(l10n.discoveryTargetHelper, style: text.bodySmall),
                  ],
                ),
              ),
            Padding(
              padding: pad.add(const EdgeInsets.only(top: AppSpacing.s16)),
              child: Wrap(
                spacing: AppSpacing.s8,
                runSpacing: AppSpacing.s8,
                children: [
                  if (!d.viewer.isReporter)
                    MeTooButton(
                      issueId: d.id,
                      enabled:
                          !offline && (d.viewer.canMeToo || !d.viewer.signedIn),
                    ),
                  FollowButton(issueId: d.id, enabled: !offline),
                  OutlinedButton.icon(
                    key: const Key('detail.share'),
                    onPressed: () => shareIssue(context, ref, d),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    icon: const Icon(
                      SaartheeIcons.share,
                      size: AppSpacing.iconSmall,
                    ),
                    label: Text(l10n.discoveryShare),
                  ),
                ],
              ),
            ),
            if (d.viewer.canLinkCcrs && !offline)
              Padding(
                padding: pad.add(const EdgeInsets.only(top: AppSpacing.s8)),
                child: SecondaryButton(
                  key: const Key('detail.addCcrs'),
                  label: l10n.discoveryAddCcrs,
                  onPressed: () => context.push('/issues/${d.id}/link-ccrs'),
                ),
              ),
            if (d.pendingReview)
              Padding(
                padding: pad.add(const EdgeInsets.only(top: AppSpacing.s8)),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: const PendingReviewTag(),
                ),
              ),
            Padding(
              padding: pad.add(const EdgeInsets.only(top: AppSpacing.s16)),
              child: switch (life) {
                AsyncValue(:final value?) => IssueLifecyclePanel(issue: value),
                AsyncValue(hasError: true) => const SizedBox.shrink(),
                _ => const SkeletonList(count: 2),
              },
            ),
          ],
        ),
      ],
    );
  }
}

/// "Before" / "After" photos (After tab hidden when there are none). The
/// first report photo carries the `issue-photo-<id>` Hero tag.
class _Photos extends StatefulWidget {
  const _Photos({required this.detail});

  final IssueDetail detail;

  @override
  State<_Photos> createState() => _PhotosState();
}

class _PhotosState extends State<_Photos> {
  bool _after = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final d = widget.detail;
    if (d.reportPhotos.isEmpty && d.afterPhotos.isEmpty) {
      return const SizedBox.shrink();
    }
    final urls = _after ? d.afterPhotos : d.reportPhotos;
    final first = urls.isEmpty ? null : urls.first;
    Widget photo = PhotoThumb(
      key: Key('detail.photo.${_after ? 'after' : 'before'}'),
      image: apiImage(first),
      semanticLabel: d.title,
      radius: 0,
    );
    if (!_after) photo = Hero(tag: 'issue-photo-${d.id}', child: photo);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        photo,
        if (d.afterPhotos.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.s8,
              AppSpacing.gutter,
              0,
            ),
            child: Wrap(
              spacing: AppSpacing.s8,
              children: [
                AppFilterChip(
                  key: const Key('detail.tab.before'),
                  label: l10n.discoveryBefore,
                  selected: !_after,
                  onSelected: (_) => setState(() => _after = false),
                ),
                AppFilterChip(
                  key: const Key('detail.tab.after'),
                  label: l10n.discoveryAfter,
                  selected: _after,
                  onSelected: (_) => setState(() => _after = true),
                ),
              ],
            ),
          ),
        if (d.blurApplied && !_after)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.s4,
              AppSpacing.gutter,
              0,
            ),
            child: Text(
              l10n.discoveryBlurCaption,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({super.key, required this.message, this.action, this.onAction});

  final String message;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    return Container(
      color: c.infoTint,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.gutter,
        vertical: AppSpacing.s12,
      ),
      child: Row(
        children: [
          Icon(SaartheeIcons.info, color: c.info),
          const SizedBox(width: AppSpacing.s8),
          Expanded(child: Text(message)),
          if (action != null)
            TertiaryButton(label: action!, onPressed: onAction),
        ],
      ),
    );
  }
}
