import 'package:flutter/material.dart';

import '../../../../core/theme/icons.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../admin_l10n.dart';
import '../../application/admin_complaints.dart';
import '../../application/admin_reference.dart';
import '../../data/models/complaint_summary.dart';
import '../../data/models/reference_data.dart';
import '../admin_format.dart';
import '../admin_paths.dart';
import '../widgets/admin_widgets.dart';
import '../widgets/complaint_list_item.dart';

/// Current All-tab filter.
final allComplaintsFilterProvider =
    NotifierProvider<AllComplaintsFilter, ComplaintFilter>(
      AllComplaintsFilter.new,
    );

class AllComplaintsFilter extends Notifier<ComplaintFilter> {
  @override
  ComplaintFilter build() => const ComplaintFilter();

  void set(ComplaintFilter filter) => state = filter;
  void clear() => state = const ComplaintFilter();
}

/// One selectable value in a filter sheet.
class _Option<T> {
  const _Option(this.value, this.label);
  final T value;
  final String label;
}

/// `/admin/complaints` (02 §4.19).
class AdminAllScreen extends ConsumerWidget {
  const AdminAllScreen({super.key});

  Future<T?> _pick<T>(
    BuildContext context,
    String title,
    List<_Option<T?>> options,
    T? current,
  ) async {
    final result = await showModalBottomSheet<_Option<T?>>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            const SizedBox(height: 8),
            for (final option in options)
              ListTile(
                minTileHeight: 56,
                leading: Icon(
                  option.value == current
                      ? SaartheeIcons.radioOn
                      : SaartheeIcons.radioOff,
                ),
                selected: option.value == current,
                title: Text(option.label),
                onTap: () => Navigator.of(context).pop(option),
              ),
          ],
        ),
      ),
    );
    if (result == null) {
      throw const _Cancelled();
    }
    return result.value;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = adminL10n(context);
    final filter = ref.watch(allComplaintsFilterProvider);
    final state = ref.watch(adminComplaintsProvider(filter));
    final notifier = ref.read(adminComplaintsProvider(filter).notifier);
    final categories = ref.watch(adminCategoriesProvider).value;
    final filterNotifier = ref.read(allComplaintsFilterProvider.notifier);

    String? categoryName(String? id) {
      if (id == null) {
        return null;
      }
      for (final c in categories ?? const <AdminCategory>[]) {
        if (c.id == id) {
          return c.name;
        }
      }
      return null;
    }

    Widget chip({
      required String label,
      required String? value,
      required Future<void> Function() onTap,
      required String key,
    }) => FilterChip(
      key: Key(key),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      selected: value != null,
      label: Text(
        value == null ? label : l10n.adminFilterChipValue(label, value),
      ),
      onSelected: (_) async {
        try {
          await onTap();
        } on _Cancelled {
          // Sheet dismissed: keep the filter.
        }
      },
    );

    final excludedLabel = switch (filter.excluded) {
      ExcludedFilter.notExcluded => null,
      ExcludedFilter.onlyExcluded => l10n.adminFilterExcludedOnly,
      ExcludedFilter.all => l10n.adminFilterExcludedAll,
    };
    final duplicateLabel = switch (filter.ccrsDuplicate) {
      null => null,
      true => l10n.adminFilterDuplicateOnly,
      false => l10n.adminFilterDuplicateNone,
    };

    final chips = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: <Widget>[
          chip(
            key: 'adminFilterSource',
            label: l10n.adminFilterSource,
            value: filter.source == null
                ? null
                : sourceLabel(l10n, filter.source!),
            onTap: () async {
              final v = await _pick<String>(
                context,
                l10n.adminFilterSource,
                <_Option<String?>>[
                  _Option<String?>(null, l10n.adminFilterAny),
                  for (final tag in allSourceTags)
                    _Option<String?>(tag, sourceLabel(l10n, tag)),
                ],
                filter.source,
              );
              filterNotifier.set(filter.copyWith(source: () => v));
            },
          ),
          const SizedBox(width: 8),
          chip(
            key: 'adminFilterCategory',
            label: l10n.adminFilterCategory,
            value: categoryName(filter.categoryId),
            onTap: () async {
              final List<AdminCategory> list =
                  categories ?? await ref.read(adminCategoriesProvider.future);
              if (!context.mounted) {
                return;
              }
              final v = await _pick<String>(
                context,
                l10n.adminFilterCategory,
                <_Option<String?>>[
                  _Option<String?>(null, l10n.adminFilterAny),
                  for (final c in list) _Option<String?>(c.id, c.name),
                ],
                filter.categoryId,
              );
              filterNotifier.set(filter.copyWith(categoryId: () => v));
            },
          ),
          const SizedBox(width: 8),
          chip(
            key: 'adminFilterStatus',
            label: l10n.adminFilterStatus,
            value: filter.status == null
                ? null
                : statusLabel(l10n, filter.status!),
            onTap: () async {
              final v = await _pick<ComplaintStatus>(
                context,
                l10n.adminFilterStatus,
                <_Option<ComplaintStatus?>>[
                  _Option<ComplaintStatus?>(null, l10n.adminFilterAny),
                  for (final s in ComplaintStatus.values)
                    _Option<ComplaintStatus?>(s, statusLabel(l10n, s)),
                ],
                filter.status,
              );
              filterNotifier.set(filter.copyWith(status: () => v));
            },
          ),
          const SizedBox(width: 8),
          chip(
            key: 'adminFilterExcluded',
            label: l10n.adminFilterExcluded,
            value: excludedLabel,
            onTap: () async {
              final v = await _pick<ExcludedFilter>(
                context,
                l10n.adminFilterExcluded,
                <_Option<ExcludedFilter?>>[
                  _Option<ExcludedFilter?>(
                    ExcludedFilter.notExcluded,
                    l10n.adminFilterExcludedHide,
                  ),
                  _Option<ExcludedFilter?>(
                    ExcludedFilter.onlyExcluded,
                    l10n.adminFilterExcludedOnly,
                  ),
                  _Option<ExcludedFilter?>(
                    ExcludedFilter.all,
                    l10n.adminFilterExcludedAll,
                  ),
                ],
                filter.excluded,
              );
              filterNotifier.set(
                filter.copyWith(excluded: v ?? ExcludedFilter.notExcluded),
              );
            },
          ),
          const SizedBox(width: 8),
          chip(
            key: 'adminFilterDuplicate',
            label: l10n.adminFilterDuplicate,
            value: duplicateLabel,
            onTap: () async {
              final v = await _pick<bool>(
                context,
                l10n.adminFilterDuplicate,
                <_Option<bool?>>[
                  _Option<bool?>(null, l10n.adminFilterAny),
                  _Option<bool?>(true, l10n.adminFilterDuplicateOnly),
                  _Option<bool?>(false, l10n.adminFilterDuplicateNone),
                ],
                filter.ccrsDuplicate,
              );
              filterNotifier.set(filter.copyWith(ccrsDuplicate: () => v));
            },
          ),
        ],
      ),
    );

    Widget list;
    if (!state.loaded && state.loading) {
      list = const AdminSkeletonList();
    } else if (!state.loaded && state.error != null) {
      list = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          AdminErrorView(
            title: l10n.adminListLoadFailed,
            error: state.error!,
            onRetry: notifier.refresh,
          ),
        ],
      );
    } else if (state.items.isEmpty) {
      list = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          AdminEmptyState(
            icon: SaartheeIcons.filterOff,
            message: l10n.adminAllEmpty,
            actionLabel: filter.hasActiveFilters
                ? l10n.adminClearFilters
                : null,
            onAction: filter.hasActiveFilters ? filterNotifier.clear : null,
          ),
        ],
      );
    } else {
      list = NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels >= n.metrics.maxScrollExtent - 400) {
            notifier.loadMore();
          }
          return false;
        },
        child: ListView.separated(
          key: const Key('adminAllList'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: adminScreenPadding,
          itemCount: state.items.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            if (i == state.items.length) {
              return LoadMoreFooter(state: state, onRetry: notifier.loadMore);
            }
            final c = state.items[i];
            return ComplaintListItem(
              key: Key('adminAllItem-${c.id}'),
              complaint: c,
              showStatus: true,
              onTap: () => context.push(AdminPaths.complaint(c.id)),
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminAllTitle)),
      body: SafeArea(
        child: AdminContentWidth(
          child: Column(
            children: <Widget>[
              chips,
              if (state.loaded && state.error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: AdminMessageBanner(
                    message: l10n.adminListLoadFailed,
                    onRetry: notifier.refresh,
                  ),
                ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: notifier.refresh,
                  child: list,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cancelled implements Exception {
  const _Cancelled();
}
