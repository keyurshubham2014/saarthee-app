import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/icons.dart';
import '../theme/tokens.dart';

/// Error row under a field: `error` icon + text, announced (DS §5 inputs).
class InlineFieldError extends StatelessWidget {
  const InlineFieldError({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.s8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(SaartheeIcons.error, color: c.error, size: AppSpacing.iconSmall),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: Text(
                message,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: c.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Text input (DS §5): label above with an "(optional)" suffix, 1 px
/// `borderStrong`, radius 14, 2 px `primary` on focus, helper below, error
/// row with icon below.
class LabeledTextField extends StatelessWidget {
  const LabeledTextField({
    super.key,
    required this.label,
    this.controller,
    this.focusNode,
    this.helper,
    this.error,
    this.optional = false,
    this.hint,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.obscureText = false,
    this.maxLines = 1,
    this.prefixIcon,
    this.autofillHints,
    this.fieldKey,
  });

  final String label;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? helper;
  final String? error;
  final bool optional;
  final String? hint;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool obscureText;
  final int maxLines;
  final IconData? prefixIcon;
  final Iterable<String>? autofillHints;
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    final text = Theme.of(context).textTheme;
    final fullLabel = optional ? '$label ${l10n.commonOptional}' : label;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(fullLabel, style: text.titleMedium),
        const SizedBox(height: AppSpacing.s8),
        TextField(
          key: fieldKey,
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          obscureText: obscureText,
          maxLines: obscureText ? 1 : maxLines,
          autofillHints: autofillHints,
          style: text.bodyLarge,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon == null
                ? null
                : Icon(prefixIcon, color: c.textSecondary),
            enabledBorder: error == null
                ? null
                : OutlineInputBorder(
                    borderRadius: AppRadii.controlRadius,
                    borderSide: BorderSide(color: c.error),
                  ),
            semanticCounterText: '',
          ).copyWith(labelText: null),
        ),
        if (helper != null) ...[
          const SizedBox(height: AppSpacing.s4),
          Text(helper!, style: text.bodySmall),
        ],
        if (error != null) InlineFieldError(message: error!),
      ],
    );
  }
}

/// One entry in an [ErrorSummary]; [onTap] moves focus to the field.
class ErrorSummaryItem {
  const ErrorSummaryItem(this.message, {this.onTap});

  final String message;
  final VoidCallback? onTap;
}

/// "There is a problem" box at the top of a form (DS §5). Requests focus
/// when shown so screen readers announce it; each item links to its field.
class ErrorSummary extends StatefulWidget {
  const ErrorSummary({super.key, required this.items, this.title});

  final List<ErrorSummaryItem> items;
  final String? title;

  @override
  State<ErrorSummary> createState() => _ErrorSummaryState();
}

class _ErrorSummaryState extends State<ErrorSummary> {
  final _focus = FocusNode(debugLabel: 'ErrorSummary');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final text = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    return Focus(
      focusNode: _focus,
      child: Semantics(
        liveRegion: true,
        container: true,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.s16),
          decoration: BoxDecoration(
            color: c.errorTint,
            borderRadius: AppRadii.cardRadius,
            border: Border.all(color: c.error, width: AppSpacing.focusWidth),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(SaartheeIcons.error, color: c.error),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: Text(
                      widget.title ?? l10n.commonErrorSummaryTitle,
                      style: text.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s8),
              for (final item in widget.items)
                item.onTap == null
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.s4,
                        ),
                        child: Text(item.message, style: text.bodyLarge),
                      )
                    : Semantics(
                        link: true,
                        child: InkWell(
                          onTap: item.onTap,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              minHeight: AppSpacing.touchTarget,
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                item.message,
                                style: text.bodyLarge?.copyWith(
                                  color: c.isDark ? c.error : c.primary,
                                  decoration: TextDecoration.underline,
                                  decorationColor: c.isDark
                                      ? c.error
                                      : c.primary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
            ],
          ),
        ),
      ),
    );
  }
}
