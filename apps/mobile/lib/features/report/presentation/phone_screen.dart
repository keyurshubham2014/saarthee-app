import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/widgets.dart';
import '../application/report_draft_controller.dart';
import 'report_step_mixin.dart';

/// Step 5: Your WhatsApp number + consent (02 §4.8).
class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key});

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen>
    with ReportStepMixin {
  @override
  String get stepRoute => ReportRoutes.phone;

  late final TextEditingController _controller = TextEditingController(
    text: ref.read(reportDraftProvider)?.phone ?? '',
  );
  bool _attempted = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _phoneValid => Validators.indianMobile(_controller.text);

  Future<void> _continue() async {
    setState(() => _attempted = true);
    final consent = ref.read(reportDraftProvider)?.consentGiven ?? false;
    if (!_phoneValid || !consent) return;
    await ref.read(reportDraftProvider.notifier).setPhone(_controller.text);
    if (mounted) goNext(ReportRoutes.check);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final consent = ref.watch(reportDraftProvider)?.consentGiven ?? false;

    return StepScaffold(
      step: 5,
      total: kReportSteps,
      title: l10n.reportPhoneTitle,
      onBack: () => goBack(ReportRoutes.photo),
      actions: [
        PrimaryButton(
          key: const Key('report.phone.continue'),
          label: l10n.commonContinue,
          onPressed: _continue,
        ),
      ],
      children: [
        Text(l10n.reportPhoneBody, style: theme.textTheme.bodyLarge),
        const SizedBox(height: AppSpacing.xl),
        TextField(
          key: const Key('report.phone.field'),
          controller: _controller,
          keyboardType: TextInputType.phone,
          autocorrect: false,
          enableSuggestions: false,
          autofillHints: const [AutofillHints.telephoneNumberNational],
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9 \-]')),
            LengthLimitingTextInputFormatter(14),
          ],
          style: theme.textTheme.bodyLarge,
          decoration: InputDecoration(
            labelText: l10n.reportPhoneLabel,
            prefixText: '${l10n.reportPhonePrefix} ',
            prefixStyle: theme.textTheme.bodyLarge,
          ),
          onChanged: (v) {
            ref.read(reportDraftProvider.notifier).setPhone(v);
            if (_attempted) setState(() {});
          },
        ),
        if (_attempted && !_phoneValid)
          InlineFieldError(message: l10n.reportPhoneError),
        const SizedBox(height: AppSpacing.xl),
        Material(
          color: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadii.cardRadius,
            side: BorderSide(
              color: _attempted && !consent
                  ? AppColors.notFixed
                  : AppColors.fieldBorder,
            ),
          ),
          child: CheckboxListTile(
            key: const Key('report.phone.consent'),
            value: consent,
            onChanged: (v) {
              ref.read(reportDraftProvider.notifier).setConsent(v ?? false);
            },
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            shape: const RoundedRectangleBorder(
              borderRadius: AppRadii.cardRadius,
            ),
            title: Text(
              l10n.reportConsentText,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ),
        if (_attempted && !consent)
          InlineFieldError(message: l10n.reportConsentError),
        const SizedBox(height: AppSpacing.md),
        Theme(
          data: theme.copyWith(dividerColor: AppColors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(
              l10n.reportWhyWeAsk,
              style: theme.textTheme.labelLarge?.copyWith(
                color: AppColors.indigo,
              ),
            ),
            childrenPadding: const EdgeInsets.only(bottom: AppSpacing.md),
            children: [
              Text(l10n.reportWhyWeAskBody, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}
