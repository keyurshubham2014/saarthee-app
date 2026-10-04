import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/application/session_controller.dart';
import '../moderation/moderation_models.dart';
import '../shared/staff_labels.dart';
import '../shared/staff_widgets.dart';
import 'staff_issue_actions.dart';
import 'staff_issue_models.dart';

/// Issue tools (TASK-10 §5.4): photos, description, place + ward, reporter
/// only as "A resident of `ward`", flags, timeline and the action bar.
class StaffIssuePanel extends ConsumerWidget {
  const StaffIssuePanel({super.key, required this.issueId, this.onHandled});

  final String issueId;

  /// Called after an action that removes the issue from a queue.
  final VoidCallback? onHandled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(staffIssueProvider(issueId));
    return StaffAsync<StaffIssue>(
      value: value,
      onRetry: () => ref.invalidate(staffIssueProvider(issueId)),
      builder: (issue) => _Body(issue: issue, onHandled: onHandled),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.issue, this.onHandled});

  final StaffIssue issue;
  final VoidCallback? onHandled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final c = SaartheeColors.of(context);
    final text = Theme.of(context).textTheme;
    final token = ref.watch(sessionProvider.select((s) => s.token));
    final headers = token == null ? null : {'Authorization': 'Bearer $token'};
    final status = issueStatusOf(issue.status);
    final ward = issue.ward;
    return ListView(
      key: Key('staff.issue.${issue.id}'),
      padding: const EdgeInsets.all(AppSpacing.gutter),
      children: [
        if (issue.hidden)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s12),
            child: NoticeBanner(key: const Key('staff.issue.hiddenBanner'), kind: NoticeKind.info, message: l10n.staffIssueHiddenBanner, rounded: true),
          ),
        Row(
          children: [
            CategoryBadge(slug: issue.categorySlug),
            const SizedBox(width: AppSpacing.s12),
            Expanded(child: Text(issue.title, style: text.titleLarge)),
            if (status != null) StatusChip(status: status) else ToneChip(tone: IssueStatusStyle.styles[IssueStatus.reported]!, label: l10n.staffStatusMerged),
          ],
        ),
        const SizedBox(height: AppSpacing.s8),
        Text(
          ward == null ? l10n.staffIssueResidentUnknown : l10n.staffIssueResident(ward.name(lang)),
          key: const Key('staff.issue.resident'),
          style: text.bodyMedium?.copyWith(color: c.textSecondary),
        ),
        Text(
          '${lang == 'gu' ? issue.categoryNameGu : issue.categoryNameEn} · ${ward == null ? l10n.moderationNoWard : l10n.staffIssueWardNumber(ward.number)} · ${issue.lat.toStringAsFixed(5)}, ${issue.lng.toStringAsFixed(5)}',
          style: text.bodySmall,
        ),
        if (issue.description != null) ...[
          const SizedBox(height: AppSpacing.s12),
          Text(issue.description!, style: text.bodyMedium),
        ],
        if (issue.photos.isNotEmpty) ...[
          StaffSectionTitle(l10n.staffIssuePhotos),
          Wrap(
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s8,
            children: [
              for (final p in issue.photos)
                SizedBox(
                  width: 160,
                  height: 120,
                  child: PhotoThumb(
                    key: Key('staff.issue.photo.${p.kind}'),
                    semanticLabel: p.kind == 'after' ? l10n.staffIssueAfter : l10n.staffIssuePhotos,
                    image: NetworkImage(Uri.parse(AppConfig.apiBaseUrl).resolve(p.url).toString(), headers: headers),
                  ),
                ),
            ],
          ),
        ],
        StaffSectionTitle(l10n.staffIssueActions),
        StaffIssueActions(issue: issue, onHandled: onHandled),
        if (issue.flags.isNotEmpty) ...[
          StaffSectionTitle(l10n.staffIssueFlags),
          for (final f in issue.flags) StaffFlagRow(issue: issue, flag: f),
        ],
        StaffSectionTitle(l10n.staffIssueTimeline),
        for (final e in issue.timeline)
          ListRow(
            key: Key('staff.issue.event.${e.id}'),
            showChevron: false,
            leading: Icon(e.hidden ? SaartheeIcons.visibilityOff : SaartheeIcons.schedule, color: c.textSecondary),
            title: e.hidden ? l10n.staffCommentHidden : staffEventLabel(l10n, e.type, e.toStatus),
            subtitle: [Formatters.dateTime(e.createdAt), if (e.note != null && !e.hidden) e.note!].join(' · '),
          ),
      ],
    );
  }
}
