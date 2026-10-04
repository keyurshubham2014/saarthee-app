import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../application/report_providers.dart';

/// Localized label of a structured reason code (TASK-05 §5.4).
String reasonLabel(AppLocalizations l10n, String slug, String code) =>
    switch ((slug, code)) {
      ('encroachment', 'footpath') => l10n.reportReasonEncFootpath,
      ('encroachment', 'road') => l10n.reportReasonEncRoad,
      ('encroachment', 'hawkers') => l10n.reportReasonEncHawkers,
      ('encroachment', _) => l10n.reportReasonEncOther,
      ('building', 'no_permission') => l10n.reportReasonBldNoPermission,
      ('building', 'unsafe') => l10n.reportReasonBldUnsafe,
      ('building', 'debris') => l10n.reportReasonBldDebris,
      _ => l10n.reportReasonBldOther,
    };

/// Single-choice list replacing the description for sensitive categories.
class SensitiveReasons extends StatelessWidget {
  const SensitiveReasons({
    super.key,
    required this.slug,
    required this.selected,
    required this.onSelected,
    this.error,
  });

  final String slug;
  final String? selected;
  final ValueChanged<String> onSelected;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    final text = Theme.of(context).textTheme;
    final codes = kStructuredReasons[slug] ?? const <String>[];
    return Column(
      key: const Key('report.reasons'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.reportFlowReasonTitle, style: text.titleSmall),
        if (error != null) InlineFieldError(message: error!),
        const SizedBox(height: AppSpacing.s8),
        for (final code in codes)
          Semantics(
            selected: selected == code,
            inMutuallyExclusiveGroup: true,
            button: true,
            child: InkWell(
              key: ValueKey('report.reason.$code'),
              borderRadius: AppRadii.controlRadius,
              onTap: () => onSelected(code),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
                child: Row(
                  children: [
                    Icon(
                      selected == code
                          ? SaartheeIcons.radioOn
                          : SaartheeIcons.radioOff,
                      color: selected == code ? c.primary : c.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: Text(
                        reasonLabel(l10n, slug, code),
                        style: text.bodyLarge,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
