import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/icons.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/discovery_models.dart';

/// "today" / "3 days ago".
String ageLabel(AppLocalizations l10n, DateTime createdAt, {DateTime? now}) {
  final days = (now ?? DateTime.now()).difference(createdAt).inDays;
  return days <= 0 ? l10n.discoveryAgeToday : l10n.discoveryAgeDays(days);
}

/// The subline under an issue title: only what the title does not already
/// say. API titles are "Category · Ward" (localised), so [parts] that the
/// title contains (category, ward) are dropped; [age] is always kept.
String issueSubline(String title, List<String?> parts, String age) {
  final extra = [
    for (final p in parts)
      if (p != null && p.isNotEmpty && !title.contains(p)) p,
  ];
  return [...extra, age].join(' · ');
}

/// Resolves a server-relative photo URL (`/api/v1/media/…`).
ImageProvider? apiImage(String? url) => url == null
    ? null
    : NetworkImage(Uri.parse(AppConfig.apiBaseUrl).resolve(url).toString());

/// An [IssueCard] for discovery lists: thumbnail, title, "Ward · age",
/// status, Me-too count; Hero tags on photo and title; tap → detail.
class IssueCardTile extends StatelessWidget {
  const IssueCardTile({
    super.key,
    required this.issue,
    this.hero = true,
    this.onTap,
    this.trailingTag,
  });

  final IssueCardData issue;

  /// Only one Hero per tag per route: lists that may repeat an id pass false.
  final bool hero;
  final VoidCallback? onTap;

  /// Extra tag under the card (e.g. "Moderator check pending").
  final Widget? trailingTag;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final ward = issue.wardName(lang);
    final age = ageLabel(l10n, issue.createdAt);
    final card = IssueCard(
      key: Key('issueCard.${issue.id}'),
      heroId: hero ? issue.id : null,
      title: issue.title,
      categorySlug: issue.categorySlug,
      wardAndAge: issueSubline(issue.title, [ward], age),
      status: issue.status,
      meTooCount: issue.meTooCount,
      overdue: issue.isOverdue,
      photo: apiImage(issue.thumbnailUrl),
      photoLabel: issue.thumbnailUrl == null ? null : issue.title,
      onTap: onTap ?? () => context.push('/issues/${issue.id}'),
    );
    if (trailingTag == null) return card;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [card, trailingTag!],
    );
  }
}

/// "Moderator check pending" on the reporter's own hidden issue.
class PendingReviewTag extends StatelessWidget {
  const PendingReviewTag({super.key});

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    return TagLabel(
      key: const Key('tag.pendingReview'),
      label: AppLocalizations.of(context).discoveryPendingReview,
      icon: SaartheeIcons.hourglass,
      foreground: c.warning,
      background: c.warningTint,
    );
  }
}
