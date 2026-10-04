import 'package:flutter/material.dart' hide ErrorSummary;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../application/report_draft_controller.dart';
import '../application/report_providers.dart';
import '../application/submit_controller.dart';
import 'report_errors.dart';
import 'sensitive_reasons.dart';

/// Step 3 "Add details and check" (TASK-05 §5.4): description (or the
/// structured choices for sensitive categories), summary with Change links,
/// the consent line and the pinned `sunrise` "Submit report".
class StepDetails extends ConsumerStatefulWidget {
  const StepDetails({super.key});

  @override
  ConsumerState<StepDetails> createState() => _StepDetailsState();
}

class _StepDetailsState extends ConsumerState<StepDetails> {
  late final TextEditingController _text = TextEditingController(
    text: ref.read(reportDraftProvider)?.description ?? '',
  );
  bool _reasonMissing = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final draft = ref.read(reportDraftProvider);
    if (draft == null) return;
    final sensitive =
        ref
            .read(reportCategoriesProvider)
            .value
            ?.bySlug(draft.categorySlug)
            ?.sensitive ??
        kStructuredReasons.containsKey(draft.categorySlug);
    if (sensitive && draft.structuredReason == null) {
      setState(() => _reasonMissing = true);
      return;
    }
    final issue = await ref.read(submitControllerProvider.notifier).submit();
    if (issue != null && mounted) context.go('/report/done');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final text = Theme.of(context).textTheme;
    final draft = ref.watch(reportDraftProvider);
    final submit = ref.watch(submitControllerProvider);
    // Offline: resend with the same clientSubmissionId when back online.
    ref.listen(isOnlineProvider, (prev, next) {
      if (next.value == true &&
          prev?.value != true &&
          ref.read(submitControllerProvider).waitingForNetwork) {
        _submit();
      }
    });
    if (draft == null) return const SizedBox.shrink();
    final slug = draft.categorySlug ?? 'other';
    final sensitive = kStructuredReasons.containsKey(slug);
    final ctl = ref.read(reportDraftProvider.notifier);
    final error = submit.error;
    final errView = error == null || error.isOffline
        ? null
        : reportError(l10n, error);
    final uploading = !draft.allUploaded;
    return Column(
      children: [
        if (submit.waitingForNetwork)
          NoticeBanner(
            kind: NoticeKind.offline,
            message: l10n.commonOfflineBanner,
          ),
        Expanded(
          child: ListView(
            key: const Key('report.details'),
            padding: const EdgeInsets.all(AppSpacing.gutter),
            children: [
              if (errView != null) ...[
                ErrorSummary(
                  key: const Key('report.errorSummary'),
                  items: [
                    ErrorSummaryItem(
                      errView.message,
                      onTap: errView.step == null
                          ? null
                          : () => ctl.goTo(errView.step!),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s16),
              ],
              Semantics(
                header: true,
                child: Text(
                  l10n.reportFlowStepDetailsTitle,
                  style: text.headlineSmall,
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
              if (sensitive)
                SensitiveReasons(
                  slug: slug,
                  selected: draft.structuredReason,
                  error: _reasonMissing ? l10n.reportFlowReasonRequired : null,
                  onSelected: (code) {
                    setState(() => _reasonMissing = false);
                    ctl.setReason(code);
                  },
                )
              else ...[
                LabeledTextField(
                  fieldKey: const Key('report.description'),
                  label: l10n.reportFlowDescriptionLabel,
                  optional: true,
                  hint: l10n.reportFlowDescriptionHint,
                  controller: _text,
                  maxLines: 4,
                  onChanged: (v) {
                    ctl.setDescription(v);
                    setState(() {});
                  },
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    l10n.reportFlowCharCount(_text.text.length),
                    style: text.bodySmall,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.s16),
              _SummaryRow(
                label: l10n.reportFlowSummaryCategory,
                value: categoryLabel(l10n, slug),
                onChange: () => ctl.goTo(ReportStep.what),
              ),
              _SummaryRow(
                label: l10n.reportFlowSummaryPhotos,
                value: l10n.reportFlowPhotoCount(draft.photos.length),
                onChange: () => ctl.goTo(ReportStep.photo),
              ),
              _SummaryRow(
                label: l10n.reportFlowSummaryPlace,
                value: draft.ward?.name(lang) ?? l10n.reportFlowNone,
                onChange: () => ctl.goTo(ReportStep.photo),
              ),
              if (!sensitive)
                _SummaryRow(
                  label: l10n.reportFlowSummaryDescription,
                  value: draft.description.trim().isEmpty
                      ? l10n.reportFlowNone
                      : draft.description.trim(),
                  onChange: null,
                ),
              const SizedBox(height: AppSpacing.s16),
              Text(l10n.reportFlowConsent, style: text.bodyMedium),
              if (uploading) ...[
                const SizedBox(height: AppSpacing.s8),
                Text(l10n.reportFlowPhotosPending, style: text.bodySmall),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          child: SubmitReportButton(
            key: const Key('report.submit'),
            label: l10n.reportFlowSubmit,
            isLoading: submit.sending,
            onPressed: submit.sending || uploading ? null : _submit,
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value, this.onChange});

  final String label;
  final String value;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: text.labelMedium),
                Text(value, style: text.bodyLarge),
              ],
            ),
          ),
          if (onChange != null)
            TextButton(onPressed: onChange, child: Text(l10n.commonChange)),
        ],
      ),
    );
  }
}
