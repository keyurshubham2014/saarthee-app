import 'package:flutter/material.dart';

import '../../../../core/theme/icons.dart';

import '../admin_l10n.dart';
import '../../application/admin_complaints.dart';
import '../../data/models/complaint_summary.dart';
import '../admin_format.dart';
import 'admin_tokens.dart';
import 'admin_widgets.dart';

/// Compact list card for Due and All (02 §4.18, §4.19).
class ComplaintListItem extends StatelessWidget {
  const ComplaintListItem({
    super.key,
    required this.complaint,
    required this.onTap,
    this.showStatus = false,
    this.action,
  });

  final ComplaintSummary complaint;
  final VoidCallback onTap;
  final bool showStatus;

  /// Optional trailing action (Due: "Send reminder").
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final l10n = adminL10n(context);
    final theme = Theme.of(context);
    final tokens = AdminTokens.of(context);
    final c = complaint;
    final ageLine = c.lastReminderAt != null
        ? l10n.adminLastReminderDaysAgo(daysSince(c.lastReminderAt!))
        : l10n.adminFiledDaysAgo(daysSince(c.createdAt));
    final thumbs = <Widget>[
      if (c.anonymized)
        AdminPhotoPlaceholder(
          size: 72,
          label: l10n.adminErrorPhotoDeleted,
          icon: SaartheeIcons.hideImage,
        )
      else
        AdminPhoto(
          size: 72,
          provider: adminReportPhotoProvider(c.id),
          semanticLabel: l10n.adminPhotoBeforeSemantics,
        ),
    ];
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ...thumbs,
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(c.ccrsNumber, style: theme.textTheme.titleMedium),
                        Text(c.categoryName, style: theme.textTheme.bodyMedium),
                        Text(
                          c.groupLabel ?? l10n.adminNoGroup,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: tokens.textMuted,
                          ),
                        ),
                        Text(
                          '$ageLine · ${l10n.adminReminderCount(c.reminderCount)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: tokens.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (showStatus ||
                  c.isExcluded ||
                  c.ccrsDuplicate ||
                  c.anonymized) ...<Widget>[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: <Widget>[
                    if (showStatus) AdminStatusChip(status: c.status),
                    if (c.isExcluded)
                      AdminTag(
                        icon: SaartheeIcons.block,
                        label: l10n.adminTagExcluded,
                        background: tokens.notFixedTint,
                        foreground: tokens.text,
                      ),
                    if (c.ccrsDuplicate)
                      AdminTag(
                        icon: SaartheeIcons.copy,
                        label: l10n.adminTagDuplicate,
                        background: tokens.waitingTint,
                        foreground: tokens.text,
                      ),
                    if (c.anonymized)
                      AdminTag(
                        icon: SaartheeIcons.personOff,
                        label: l10n.adminTagAnonymized,
                        background: tokens.neutralTint,
                        foreground: tokens.text,
                      ),
                  ],
                ),
              ],
              if (action != null) ...<Widget>[
                const SizedBox(height: 12),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Footer row for paged lists: spinner, inline retry, or nothing.
class LoadMoreFooter extends StatelessWidget {
  const LoadMoreFooter({super.key, required this.state, required this.onRetry});

  final ComplaintListState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = adminL10n(context);
    if (state.loadingMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: AdminMessageBanner(
          message: l10n.adminLoadMoreFailed,
          onRetry: onRetry,
        ),
      );
    }
    return const SizedBox(height: 24);
  }
}
