import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/app_error.dart';
import '../../../core/settings/locale_controller.dart';
import '../data/discovery_api.dart';
import '../data/discovery_models.dart';

/// Paged issue list state (`/issues`, My reports, Following).
class IssueListState {
  const IssueListState({
    this.items = const [],
    this.nextCursor,
    this.loaded = false,
    this.loadingMore = false,
    this.refreshing = false,
    this.error,
    this.newIds = const {},
  });

  final List<IssueCardData> items;
  final String? nextCursor;
  final bool loaded, loadingMore, refreshing;
  final AppError? error;

  /// Ids that were not in the list before the last refresh (they rise in).
  final Set<String> newIds;

  bool get endReached => loaded && nextCursor == null;

  IssueListState copyWith({
    List<IssueCardData>? items,
    String? nextCursor,
    bool clearCursor = false,
    bool? loaded,
    bool? loadingMore,
    bool? refreshing,
    AppError? error,
    bool clearError = false,
    Set<String>? newIds,
  }) => IssueListState(
    items: items ?? this.items,
    nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
    loaded: loaded ?? this.loaded,
    loadingMore: loadingMore ?? this.loadingMore,
    refreshing: refreshing ?? this.refreshing,
    error: clearError ? null : (error ?? this.error),
    newIds: newIds ?? this.newIds,
  );
}

final issueListProvider = NotifierProvider.autoDispose
    .family<IssueListController, IssueListState, IssueQuery>(
      IssueListController.new,
    );

class IssueListController extends Notifier<IssueListState> {
  IssueListController(this.query);

  final IssueQuery query;
  int _generation = 0;

  DiscoveryApi get _api => ref.read(discoveryApiProvider);
  String get _lang => ref.read(localeProvider).languageCode;

  @override
  IssueListState build() {
    Future.microtask(refresh);
    return const IssueListState();
  }

  /// First page (initial load and pull to refresh). Items not in the
  /// previous list are marked new, so only they rise in.
  Future<void> refresh() async {
    final gen = ++_generation;
    final before = {for (final i in state.items) i.id};
    state = state.copyWith(refreshing: true, clearError: true);
    try {
      final page = await _api.list(query, lang: _lang);
      if (gen != _generation || !ref.mounted) return;
      state = IssueListState(
        items: page.items,
        nextCursor: page.nextCursor,
        loaded: true,
        newIds: state.loaded
            ? {
                for (final i in page.items)
                  if (!before.contains(i.id)) i.id,
              }
            : const {},
      );
    } catch (e) {
      if (gen != _generation || !ref.mounted) return;
      state = state.copyWith(refreshing: false, error: AppError.from(e));
    }
  }

  /// Next page (infinite scroll); de-duplicates by id.
  Future<void> loadMore() async {
    final cursor = state.nextCursor;
    if (cursor == null || state.loadingMore) return;
    final gen = _generation;
    state = state.copyWith(loadingMore: true);
    try {
      final page = await _api.list(query, cursor: cursor, lang: _lang);
      if (gen != _generation || !ref.mounted) return;
      final seen = {for (final i in state.items) i.id};
      state = state.copyWith(
        items: [
          ...state.items,
          ...page.items.where((i) => !seen.contains(i.id)),
        ],
        nextCursor: page.nextCursor,
        clearCursor: page.nextCursor == null,
        loadingMore: false,
        newIds: const {},
      );
    } catch (e) {
      if (gen != _generation || !ref.mounted) return;
      state = state.copyWith(loadingMore: false, error: AppError.from(e));
    }
  }

  /// Drops an item locally (Following → Unfollow).
  void remove(String id) => state = state.copyWith(
    items: state.items.where((i) => i.id != id).toList(),
  );
}
