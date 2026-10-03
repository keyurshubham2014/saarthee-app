import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Visual tone of a selected [ChoiceCard].
enum ChoiceTone { neutral, fixed, notFixed }

/// Large selectable option. Selection shows a check icon and border, never
/// colour alone (02 §2.3).
class ChoiceCard extends StatelessWidget {
  const ChoiceCard({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.description,
    this.icon,
    this.tone = ChoiceTone.neutral,
  });

  final String label;
  final String? description;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  final ChoiceTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (Color accent, Color tint) = switch (tone) {
      ChoiceTone.neutral => (AppColors.indigo, AppColors.indigoTint),
      ChoiceTone.fixed => (AppColors.fixed, AppColors.fixedTint),
      ChoiceTone.notFixed => (AppColors.notFixed, AppColors.notFixedTint),
    };
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected ? tint : AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.cardRadius,
          side: BorderSide(
            color: selected ? accent : AppColors.fieldBorder,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: AppRadii.cardRadius,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: selected ? accent : AppColors.ink),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: theme.textTheme.bodyLarge),
                        if (description != null)
                          Text(description!, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: selected ? accent : AppColors.fieldBorder,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
