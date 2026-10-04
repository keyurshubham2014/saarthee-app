import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/motion/rise_in.dart';
import '../../../core/motion/staggered.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../application/issue_list_controller.dart';
import '../data/discovery_api.dart';
import '../data/discovery_models.dart';
import 'widgets/chevron_refresh_indicator.dart';
import 'widgets/issue_card_tile.dart';

/// Infinite, pull-to-refresh list of issue cards for [query] (`/issues`,
/// My reports, Following). Only items new since the last refresh rise in.
class IssueListView extends ConsumerStatefulWidget {
  const IssueListView({
    super.key,
    required this.query,
    required this.empty,
    this.header,
    this.itemExtra,
  });

  final IssueQuery query;

  /// Shown when the first page is empty.
  final Widget empty;
  final Widget? header;

  /// Optional per-item trailing widget (tags, Unfollow).
  final Widget? Function(IssueCardData item)? itemExtra;

  @override
  ConsumerState<IssueListView> createState() => _IssueListViewState();
}

class _IssueListViewState extends ConsumerState<IssueListView> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
  }

  /// Near the end (or the first page doesn't fill the screen) → next page.
  void _maybeLoadMore() {
    if (!mounted || !_scroll.hasClients) return;
    final p = _scroll.position;
    if (p.pixels > p.maxScrollExtent - 400) {
      ref.read(issueListProvider(widget.query).notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = ref.watch(issueListProvider(widget.query));
    final ctrl = ref.read(issueListProvider(widget.query).notifier);
    final scheme = SaartheeMotion.of(context);
    if (!s.loaded) {
      if (s.error != null) {
        return ErrorState(
          key: const Key('issueList.error'),
          message: l10n.discoveryLoadError,
          onRetry: ctrl.refresh,
        );
      }
      return const SkeletonList(key: Key('issueList.loading'), count: 4);
    }
    var newIndex = 0;
    if (s.nextCursor != null && !s.loadingMore && s.error == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoadMore());
    }
    return ChevronRefreshIndicator(
      onRefresh: ctrl.refresh,
      child: ListView(
        key: const Key('issueList'),
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: AppSpacing.s40),
        children: [
          ?widget.header,
          if (s.items.isEmpty) widget.empty,
          for (final i in s.items)
            Padding(
              key: ValueKey('issueList.${i.id}'),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.s8,
                AppSpacing.gutter,
                AppSpacing.s4,
              ),
              child: RiseIn(
                animate: s.newIds.contains(i.id),
                delay: s.newIds.contains(i.id)
                    ? staggerDelay(scheme, newIndex++)
                    : Duration.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IssueCardTile(issue: i),
                    ?widget.itemExtra?.call(i),
                  ],
                ),
              ),
            ),
          if (s.loadingMore) const SkeletonList(count: 1),
          if (s.endReached && s.items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.s16),
              child: Center(
                child: Text(
                  l10n.discoveryEndOfList,
                  key: const Key('issueList.end'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
