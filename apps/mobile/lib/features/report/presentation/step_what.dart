import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/motion/motion_widgets.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/application/ensure_signed_in.dart';
import '../application/report_draft_controller.dart';
import '../application/report_providers.dart';
import 'motion/category_tile.dart';

/// The 14 v2 slugs in display order (offline-first: tiles never wait for
/// the network; the server list only confirms them).
const List<String> kReportSlugs = [
  'roads', 'water', 'drainage', 'garbage', 'streetlight', 'trees', 'animals', //
  'health', 'toilets', 'encroachment', 'traffic', 'property', 'building',
  'other',
];

/// Step 1 "What is the problem?" (TASK-05 §5.4): 2-column grid of 14 tiles.
class StepWhat extends ConsumerStatefulWidget {
  const StepWhat({super.key, this.popIn = true});

  /// Tiles pop in only the first time step 1 is built for a draft.
  final bool popIn;

  @override
  ConsumerState<StepWhat> createState() => _StepWhatState();
}

class _StepWhatState extends ConsumerState<StepWhat> {
  String? _tapped;
  Timer? _go;

  @override
  void dispose() {
    _go?.cancel();
    super.dispose();
  }

  Future<void> _select(String slug) async {
    if (_tapped != null) return;
    final ok = await ensureSignedIn(context, ref, reason: SignInReason.report);
    if (!ok || !mounted) return;
    unawaited(ref.read(saartheeHapticsProvider).selection());
    setState(() => _tapped = slug);
    final wait = SaartheeMotion.of(context).short.duration;
    void go() => ref.read(reportDraftProvider.notifier).chooseCategory(slug);
    if (wait == Duration.zero) {
      go();
    } else {
      _go = Timer(wait, go);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final categories = ref.watch(reportCategoriesProvider);
    final selected =
        _tapped ??
        ref.watch(reportDraftProvider.select((d) => d?.categorySlug));
    final text = Theme.of(context).textTheme;
    final items = categories.value?.items;
    final slugs = items == null || items.isEmpty
        ? kReportSlugs
        : [for (final c in items) c.slug];
    return CustomScrollView(
      key: const Key('report.what'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.s8,
            AppSpacing.gutter,
            AppSpacing.s16,
          ),
          sliver: SliverList.list(
            children: [
              Semantics(
                header: true,
                child: Text(
                  l10n.reportFlowStepWhatTitle,
                  style: text.headlineSmall,
                ),
              ),
              if (categories.value?.fromCache == true) ...[
                const SizedBox(height: AppSpacing.s12),
                NoticeBanner(
                  kind: NoticeKind.offline,
                  message: l10n.reportFlowCategoriesOffline,
                  rounded: true,
                ),
              ],
              if (categories.hasError && !categories.isLoading) ...[
                const SizedBox(height: AppSpacing.s12),
                ErrorState(
                  message: l10n.reportFlowCategoriesError,
                  onRetry: () => ref.invalidate(reportCategoriesProvider),
                ),
              ],
            ],
          ),
        ),
        if (categories.isLoading && !categories.hasValue)
          const SliverToBoxAdapter(
            key: Key('report.what.skeleton'),
            child: SkeletonList(count: 4),
          )
        else if (categories.hasValue)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              0,
              AppSpacing.gutter,
              AppSpacing.s24,
            ),
            sliver: SliverGrid.builder(
              itemCount: slugs.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: AppSpacing.cardGap,
                crossAxisSpacing: AppSpacing.cardGap,
                mainAxisExtent: 112,
              ),
              itemBuilder: (context, i) {
                final slug = slugs[i];
                return CategoryTile(
                  slug: slug,
                  label: categoryLabel(l10n, slug),
                  index: i,
                  selected: selected == slug,
                  popIn: widget.popIn,
                  onTap: () => _select(slug),
                );
              },
            ),
          ),
      ],
    );
  }
}
