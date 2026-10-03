import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/widgets.dart';
import '../application/report_draft_controller.dart';
import 'report_step_mixin.dart';

/// Step 3: Your AMC complaint number (02 §4.6).
class NumberScreen extends ConsumerStatefulWidget {
  const NumberScreen({super.key});

  @override
  ConsumerState<NumberScreen> createState() => _NumberScreenState();
}

class _NumberScreenState extends ConsumerState<NumberScreen>
    with ReportStepMixin {
  @override
  String get stepRoute => ReportRoutes.number;

  late final TextEditingController _controller = TextEditingController(
    text: ref.read(reportDraftProvider)?.ccrsNumber ?? '',
  );
  bool _attempted = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _valid => Validators.ccrsNumber(_controller.text);

  Future<void> _continue() async {
    setState(() => _attempted = true);
    if (!_valid) return;
    await ref
        .read(reportDraftProvider.notifier)
        .setCcrsNumber(_controller.text);
    if (mounted) goNext(ReportRoutes.photo);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return StepScaffold(
      step: 3,
      total: kReportSteps,
      title: l10n.reportNumberTitle,
      onBack: () => goBack(ReportRoutes.fileWithAmc),
      actions: [
        PrimaryButton(
          key: const Key('report.number.continue'),
          label: l10n.commonContinue,
          onPressed: _continue,
        ),
      ],
      children: [
        TextField(
          key: const Key('report.number.field'),
          controller: _controller,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.characters,
          maxLength: 50,
          style: theme.textTheme.bodyLarge,
          decoration: InputDecoration(
            labelText: l10n.reportNumberLabel,
            helperText: l10n.reportNumberHelp,
            helperMaxLines: 3,
            counterText: '',
          ),
          // Validate on Continue, then live after the first failed attempt.
          onChanged: (_) {
            if (_attempted) setState(() {});
          },
          onEditingComplete: _continue,
        ),
        if (_attempted && !_valid)
          InlineFieldError(message: l10n.reportNumberError),
      ],
    );
  }
}
