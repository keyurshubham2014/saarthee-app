import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/motion/transitions.dart';
import '../../../core/settings/locale_controller.dart';
import '../../../core/theme/icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/wards/ward.dart';
import '../../../core/wards/ward_providers.dart';
import '../../../core/wards/ward_search.dart';
import '../../../core/widgets/widgets.dart';

/// Opens the full-screen ward picker (slides up with `springIn`). Returns
/// the chosen ward, or null when dismissed.
Future<Ward?> showWardPicker(BuildContext context) => showSaartheeSheet<Ward>(
  context: context,
  fullScreen: true,
  builder: (_) => const WardPickerSheet(),
);

/// Search + zone-grouped ward list (TASK-03 §5.4). Loading = shimmering
/// skeleton rows that cross-fade to the list; cache + offline banner when
/// the API is unreachable; error state with "Try again" when nothing is
/// cached; "No ward matches" for an empty search.
class WardPickerSheet extends ConsumerStatefulWidget {
  const WardPickerSheet({super.key});

  @override
  ConsumerState<WardPickerSheet> createState() => _WardPickerSheetState();
}

class _WardPickerSheetState extends ConsumerState<WardPickerSheet> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final lang = ref.watch(localeProvider).languageCode;
    final async = ref.watch(wardsListProvider);

    final loading = async.isLoading && !async.hasValue;
    Widget content = const SizedBox.shrink();
    if (async.hasError && !async.isLoading) {
      content = ListView(
        children: [
          ErrorState(
            key: const Key('wardPicker.error'),
            message: l10n.wardPickerError,
            onRetry: () => ref.invalidate(wardsListProvider),
          ),
        ],
      );
    } else if (async.hasValue) {
      final result = async.requireValue;
      final groups = groupAndFilter(result.wards, _query);
      content = Column(
        key: const Key('wardPicker.list'),
        children: [
          if (result.fromCache) const NoticeBanner(kind: NoticeKind.offline),
          Expanded(
            child: groups.isEmpty
                ? ListView(
                    children: [
                      EmptyState(
                        icon: SaartheeIcons.searchOff,
                        message: l10n.wardPickerNoMatch(_query.trim()),
                      ),
                    ],
                  )
                : _GroupedList(
                    groups: groups,
                    lang: lang,
                    onPick: (w) => Navigator.of(context).pop(w),
                  ),
          ),
        ],
      );
    }

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s4,
              AppSpacing.s8,
              AppSpacing.gutter,
              0,
            ),
            child: Row(
              children: [
                IconButton(
                  tooltip: l10n.commonClose,
                  icon: const Icon(SaartheeIcons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      l10n.wardPickerTitle,
                      style: text.headlineSmall,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.gutter),
            child: TextField(
              key: const Key('wardPicker.search'),
              controller: _search,
              onChanged: (v) => setState(() => _query = v),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l10n.wardPickerSearch,
                prefixIcon: const Icon(SaartheeIcons.search),
              ),
            ),
          ),
          Expanded(
            child: SkeletonSwitcher(
              loading: loading,
              skeleton: const SkeletonList(key: Key('wardPicker.skeleton')),
              child: content,
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupedList extends StatelessWidget {
  const _GroupedList({
    required this.groups,
    required this.lang,
    required this.onPick,
  });

  final List<ZoneGroup> groups;
  final String lang;
  final ValueChanged<Ward> onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    final text = Theme.of(context).textTheme;
    return ListView(
      children: [
        for (final g in groups) ...[
          Container(
            key: ValueKey('wardPicker.zone.${g.zone.id}'),
            color: c.background,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.s16,
              AppSpacing.gutter,
              AppSpacing.s8,
            ),
            child: Semantics(
              header: true,
              child: Text(
                l10n.wardZone(g.zone.name(lang)),
                style: text.titleMedium?.copyWith(color: c.textSecondary),
              ),
            ),
          ),
          for (final w in g.wards)
            ListRow(
              key: ValueKey('wardPicker.ward.${w.id}'),
              title: w.shortLabel(lang),
              subtitle: l10n.wardZone(w.zone.name(lang)),
              showChevron: false,
              onTap: () => onPick(w),
            ),
        ],
      ],
    );
  }
}
