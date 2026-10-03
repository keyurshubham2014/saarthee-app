import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/event_queue.dart';
import '../../../core/config/app_config.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../application/handoff_launcher.dart';
import '../application/report_draft_controller.dart';
import 'report_step_mixin.dart';

/// Step 2: File it with AMC (02 §4.5). The draft (with this step) is saved
/// before leaving the app, so a cold start reopens here.
class FileWithAmcScreen extends ConsumerStatefulWidget {
  const FileWithAmcScreen({super.key});

  @override
  ConsumerState<FileWithAmcScreen> createState() => _FileWithAmcScreenState();
}

class _FileWithAmcScreenState extends ConsumerState<FileWithAmcScreen>
    with ReportStepMixin {
  @override
  String get stepRoute => ReportRoutes.fileWithAmc;

  bool _openFailed = false;

  Future<void> _open(HandoffTarget target) async {
    // Persist the draft on this step BEFORE leaving the app.
    await ref.read(reportDraftProvider.notifier).setStep(stepRoute);
    ref.read(eventQueueProvider).track(AppEvents.ccrsHandoffClicked, {
      'target': target.name,
    });
    final ok = await ref.read(handoffLauncherProvider).open(target);
    if (mounted) setState(() => _openFailed = !ok);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final draft = ref.watch(reportDraftProvider);
    return StepScaffold(
      step: 2,
      total: kReportSteps,
      title: l10n.reportAmcTitle,
      onBack: () => goBack(ReportRoutes.category),
      actions: [
        PrimaryButton(
          key: const Key('report.amc.continue'),
          label: l10n.reportAmcHaveNumber,
          onPressed: () => goNext(ReportRoutes.number),
        ),
      ],
      children: [
        Text(l10n.reportAmcBody, style: theme.textTheme.bodyLarge),
        if (draft?.categoryName != null) ...[
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: const BoxDecoration(
              color: AppColors.indigoTint,
              borderRadius: AppRadii.cardRadius,
            ),
            child: Text(
              l10n.reportAmcChosenCategory(draft!.categoryName!),
              style: theme.textTheme.bodyLarge,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        SecondaryButton(
          key: const Key('report.amc.web'),
          label: l10n.reportAmcWeb,
          icon: Icons.open_in_new_rounded,
          onPressed: () => _open(HandoffTarget.web),
        ),
        const SizedBox(height: AppSpacing.md),
        SecondaryButton(
          key: const Key('report.amc.whatsapp'),
          label: l10n.reportAmcWhatsapp,
          icon: Icons.chat_rounded,
          onPressed: () => _open(HandoffTarget.whatsapp),
        ),
        const SizedBox(height: AppSpacing.md),
        SecondaryButton(
          key: const Key('report.amc.call'),
          label: l10n.reportAmcCall(AppConfig.amcHelpline),
          icon: Icons.call_rounded,
          onPressed: () => _open(HandoffTarget.call),
        ),
        if (_openFailed) InlineFieldError(message: l10n.reportAmcOpenFailed),
      ],
    );
  }
}
