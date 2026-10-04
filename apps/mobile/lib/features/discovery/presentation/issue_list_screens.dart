import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/wards/ward_providers.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/application/ensure_signed_in.dart';
import '../../auth/application/session_controller.dart';
import '../application/issue_list_controller.dart';
import '../data/discovery_api.dart';
import 'issue_list_view.dart';
import 'widgets/issue_card_tile.dart';

const _categories = [
  'roads',
  'water',
  'drainage',
  'garbage',
  'streetlight',
  'trees',
  'animals',
  'health',
  'toilets',
  'encroachment',
  'traffic',
  'property',
  'building',
  'other',
];

/// Category multi-select sheet (radius 24 top corners); null = cancelled.
Future<Set<String>?> pickCategories(BuildContext context, Set<String> current) {
  final l10n = AppLocalizations.of(context);
  var picked = {...current};
  return showModalBottomSheet<Set<String>>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheetTop),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.gutter),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.discoveryFilterCategory,
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.s12),
                Wrap(
                  spacing: AppSpacing.s8,
                  runSpacing: AppSpacing.s8,
                  children: [
                    for (final slug in _categories)
                      AppFilterChip(
                        key: Key('categorySheet.$slug'),
                        label: categoryLabel(l10n, slug),
                        selected: picked.contains(slug),
                        onSelected: (on) => setState(() {
                          picked = on
                              ? {...picked, slug}
                              : ({...picked}..remove(slug));
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s16),
                PrimaryButton(
                  key: const Key('categorySheet.done'),
                  label: l10n.discoveryDone,
                  onPressed: () => Navigator.of(ctx).pop(picked),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// `/issues?ward=&bbox=` — filter chips (Category sheet, status), sort menu,
/// infinite list, empty "Clear filters", end "That's all.".
class IssuesScreen extends ConsumerStatefulWidget {
  const IssuesScreen({super.key, this.wardId, this.bbox});

  final String? wardId;
  final String? bbox;

  @override
  ConsumerState<IssuesScreen> createState() => _IssuesScreenState();
}

class _IssuesScreenState extends ConsumerState<IssuesScreen> {
  late IssueQuery _q = IssueQuery(wardId: widget.wardId, bbox: widget.bbox);

  void _toggleStatus(String g) => setState(() {
    final s = {..._q.statuses};
    if (!s.remove(g)) s.add(g);
    _q = _q.copyWith(statuses: s);
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final home = ref.watch(homeWardProvider);
    final title = widget.wardId != null && home?.id == widget.wardId
        ? l10n.discoveryIssuesTitle(home!.name(lang))
        : l10n.discoveryIssuesTitleAll;
    final sorts = {
      'newest': l10n.discoverySortNewest,
      'most_affected': l10n.discoverySortAffected,
      'overdue': l10n.discoverySortOverdue,
    };
    final groups = {
      'open': l10n.discoveryStatusOpen,
      'overdue': l10n.discoveryStatusOverdue,
      'fixed': l10n.discoveryStatusFixed,
      'verified': l10n.discoveryStatusVerified,
    };
    final filters = SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
        children: [
          AppFilterChip(
            key: const Key('issues.filter.category'),
            label: _q.categories.isEmpty
                ? l10n.discoveryFilterCategory
                : '${l10n.discoveryFilterCategory} (${_q.categories.length})',
            icon: SaartheeIcons.category,
            selected: _q.categories.isNotEmpty,
            onSelected: (_) async {
              final picked = await pickCategories(context, _q.categories);
              if (picked != null) {
                setState(() => _q = _q.copyWith(categories: picked));
              }
            },
          ),
          for (final g in groups.entries)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: AppSpacing.s8),
              child: AppFilterChip(
                key: Key('issues.filter.${g.key}'),
                label: g.value,
                selected: _q.statuses.contains(g.key),
                onSelected: (_) => _toggleStatus(g.key),
              ),
            ),
        ],
      ),
    );
    return Scaffold(
      appBar: SaartheeAppBar(
        title: title,
        actions: [
          PopupMenuButton<String>(
            key: const Key('issues.sort'),
            tooltip: l10n.discoverySort,
            icon: const Icon(SaartheeIcons.listAlt),
            initialValue: _q.sort,
            onSelected: (v) => setState(() => _q = _q.copyWith(sort: v)),
            itemBuilder: (_) => [
              for (final e in sorts.entries)
                PopupMenuItem(
                  key: Key('issues.sort.${e.key}'),
                  value: e.key,
                  child: Text(e.value),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          filters,
          Expanded(
            child: IssueListView(
              key: ValueKey(_q),
              query: _q,
              empty: EmptyState(
                key: const Key('issues.empty'),
                icon: SaartheeIcons.filterOff,
                message: l10n.discoveryNoMatch,
                actionLabel: _q.hasFilters ? l10n.discoveryClearFilters : null,
                onAction: _q.hasFilters
                    ? () => setState(
                        () => _q = _q.copyWith(categories: {}, statuses: {}),
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignedOut extends ConsumerWidget {
  const _SignedOut({required this.message});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) => EmptyState(
    key: const Key('issues.signedOut'),
    icon: SaartheeIcons.person,
    message: message,
    actionLabel: AppLocalizations.of(context).discoverySignIn,
    onAction: () => ensureSignedIn(context, ref, reason: SignInReason.generic),
  );
}

/// `/me/reports`: own issues incl. hidden ("Moderator check pending").
class MyReportsScreen extends ConsumerWidget {
  const MyReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final signedIn = ref.watch(sessionProvider.select((s) => s.signedIn));
    return Scaffold(
      appBar: SaartheeAppBar(title: l10n.discoveryMyReportsTitle),
      body: !signedIn
          ? _SignedOut(message: l10n.discoveryMyReportsSignedOut)
          : IssueListView(
              query: const IssueQuery(mine: true),
              itemExtra: (i) => i.pendingReview
                  ? const Padding(
                      padding: EdgeInsets.only(top: AppSpacing.s4),
                      child: PendingReviewTag(),
                    )
                  : null,
              empty: EmptyState(
                key: const Key('myReports.empty'),
                message: l10n.discoveryMyReportsEmpty,
                actionLabel: l10n.homeReportCardTitle,
                onAction: () => context.go('/report'),
              ),
            ),
    );
  }
}

/// `/me/following`: followed issues with "Unfollow".
class FollowingScreen extends ConsumerWidget {
  const FollowingScreen({super.key});

  static const _query = IssueQuery(following: true);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final signedIn = ref.watch(sessionProvider.select((s) => s.signedIn));
    return Scaffold(
      appBar: SaartheeAppBar(title: l10n.discoveryFollowingTitle),
      body: !signedIn
          ? _SignedOut(message: l10n.discoveryFollowingSignedOut)
          : IssueListView(
              query: _query,
              itemExtra: (i) => Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TertiaryButton(
                  key: Key('following.unfollow.${i.id}'),
                  label: l10n.discoveryUnfollow,
                  onPressed: () async {
                    ref.read(issueListProvider(_query).notifier).remove(i.id);
                    try {
                      await ref
                          .read(discoveryApiProvider)
                          .follow(i.id, on: false);
                    } catch (_) {
                      ref.invalidate(issueListProvider(_query));
                    }
                  },
                ),
              ),
              empty: EmptyState(
                key: const Key('following.empty'),
                icon: SaartheeIcons.follow,
                message: l10n.discoveryFollowingEmpty,
              ),
            ),
    );
  }
}
