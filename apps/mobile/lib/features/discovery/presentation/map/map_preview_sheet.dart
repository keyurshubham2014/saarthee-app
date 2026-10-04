import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/widgets.dart';
import '../../application/discovery_providers.dart';
import '../../data/discovery_models.dart';
import '../widgets/issue_card_tile.dart';

/// Pin tap → bottom sheet (radius 24 top) with the issue card and
/// "View details"; slides up with `springIn` (instant when reduced).
Future<void> showMapPreview(BuildContext context, String issueId) {
  final spec = SaartheeMotion.of(context).springIn;
  return showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheetTop),
    sheetAnimationStyle: AnimationStyle(
      duration: spec.duration,
      curve: spec.curve,
    ),
    builder: (_) => MapPreviewSheet(issueId: issueId),
  );
}

class MapPreviewSheet extends ConsumerWidget {
  const MapPreviewSheet({super.key, required this.issueId});

  final String issueId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(issueDetailProvider(issueId));
    return SafeArea(
      child: Padding(
        key: const Key('map.preview'),
        padding: const EdgeInsets.all(AppSpacing.gutter),
        child: switch (async) {
          AsyncValue(:final value?) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IssueCardTile(
                issue: _card(value.issue),
                onTap: () => _open(context),
              ),
              const SizedBox(height: AppSpacing.s12),
              PrimaryButton(
                key: const Key('map.preview.details'),
                label: l10n.discoveryMapViewDetails,
                onPressed: () => _open(context),
              ),
            ],
          ),
          AsyncValue(hasError: true) => Text(l10n.discoveryNotAvailable),
          _ => const SkeletonList(count: 1),
        },
      ),
    );
  }

  void _open(BuildContext context) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push('/issues/$issueId');
  }

  static IssueCardData _card(IssueDetail d) => IssueCardData(
    id: d.id,
    title: d.title,
    categorySlug: d.categorySlug,
    status: d.status,
    isOverdue: d.isOverdue,
    createdAt: d.createdAt,
    meTooCount: d.meTooCount,
    wardNameEn: d.wardNameEn,
    wardNameGu: d.wardNameGu,
    thumbnailUrl: d.reportPhotos.isEmpty ? null : d.reportPhotos.first,
  );
}
