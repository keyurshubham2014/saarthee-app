import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/app_error.dart';
import '../../../core/api/error_messages.dart';
import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../application/report_draft_controller.dart';
import 'report_step_mixin.dart';

/// Step 1: What kind of problem? (02 §4.4)
class CategoryScreen extends ConsumerStatefulWidget {
  const CategoryScreen({super.key});

  @override
  ConsumerState<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends ConsumerState<CategoryScreen>
    with ReportStepMixin {
  @override
  String get stepRoute => ReportRoutes.category;

  String? _selectedId;
  bool _showRequired = false;

  @override
  void initState() {
    super.initState();
    // A new draft gets its clientSubmissionId here; emits report_opened.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(reportDraftProvider.notifier).start();
      if (mounted) {
        setState(() => _selectedId = ref.read(reportDraftProvider)?.categoryId);
      }
    });
  }

  Future<void> _continue() async {
    final cats = ref.read(categoriesProvider).value ?? const [];
    final chosen = cats.where((c) => c.id == _selectedId).firstOrNull;
    if (chosen == null) {
      setState(() => _showRequired = true);
      return;
    }
    await ref.read(reportDraftProvider.notifier).setCategory(chosen);
    if (mounted) goNext(ReportRoutes.fileWithAmc);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cats = ref.watch(categoriesProvider);
    final offline = ref.watch(isOfflineProvider);

    final List<Widget> body = cats.when(
      loading: () => [
        for (var i = 0; i < 5; i++) ...[
          const SkeletonBox(),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
      error: (e, _) => [
        EmptyState(
          icon: Icons.cloud_off_rounded,
          message: e is AppError
              ? '${l10n.reportCategoryLoadFailed} ${appErrorMessage(l10n, e)}'
              : l10n.reportCategoryLoadFailed,
          actionLabel: l10n.commonRetry,
          onAction: () => ref.read(categoriesProvider.notifier).refresh(),
        ),
      ],
      data: (items) => items.isEmpty
          ? [
              EmptyState(
                message: l10n.reportCategoryEmpty,
                actionLabel: l10n.commonRetry,
                onAction: () => ref.read(categoriesProvider.notifier).refresh(),
              ),
            ]
          : [
              for (final c in items) ...[
                ChoiceCard(
                  key: Key('report.category.${c.id}'),
                  label: c.name,
                  selected: c.id == _selectedId,
                  onTap: () => setState(() {
                    _selectedId = c.id;
                    _showRequired = false;
                  }),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              if (_showRequired)
                InlineFieldError(message: l10n.reportCategoryRequired),
            ],
    );

    return StepScaffold(
      step: 1,
      total: kReportSteps,
      title: l10n.reportCategoryTitle,
      onBack: () async {
        if (fromCheck) {
          context.go(ReportRoutes.check);
          return;
        }
        // Leaving before choosing anything: no draft worth keeping.
        if (ref.read(reportDraftProvider)?.categoryId == null) {
          await ref.read(reportDraftProvider.notifier).discard();
        }
        if (context.mounted) context.go('/');
      },
      showOfflineBanner: offline,
      actions: [
        PrimaryButton(
          key: const Key('report.category.continue'),
          label: l10n.commonContinue,
          onPressed: cats.hasValue ? _continue : null,
        ),
      ],
      children: body,
    );
  }
}
