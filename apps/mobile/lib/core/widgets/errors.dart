import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/tokens.dart';

/// Inline error under a field: `notFixed` colour plus icon; announced.
class InlineFieldError extends StatelessWidget {
  const InlineFieldError({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.error_rounded,
              color: AppColors.notFixed,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppColors.notFixed),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One entry in an [ErrorSummary]; [onTap] jumps to the step/field to fix.
class ErrorSummaryItem {
  const ErrorSummaryItem(this.message, {this.onTap});

  final String message;
  final VoidCallback? onTap;
}

/// Error summary at the top of a screen (02 §6.2, §9.2). Requests focus when
/// shown so screen readers announce it (focus moves to the summary).
class ErrorSummary extends StatefulWidget {
  const ErrorSummary({super.key, required this.items, this.title});

  final List<ErrorSummaryItem> items;
  final String? title;

  @override
  State<ErrorSummary> createState() => _ErrorSummaryState();
}

class _ErrorSummaryState extends State<ErrorSummary> {
  final _focus = FocusNode();

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
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Focus(
      focusNode: _focus,
      child: Semantics(
        liveRegion: true,
        container: true,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.notFixedTint,
            borderRadius: AppRadii.cardRadius,
            border: Border.all(color: AppColors.notFixed, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.error_rounded, color: AppColors.notFixed),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      widget.title ?? l10n.commonErrorSummaryTitle,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final item in widget.items)
                item.onTap == null
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.xs,
                        ),
                        child: Text(
                          item.message,
                          style: theme.textTheme.bodyLarge,
                        ),
                      )
                    : InkWell(
                        onTap: item.onTap,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: AppSpacing.touchTarget,
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              item.message,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: AppColors.indigo,
                                decoration: TextDecoration.underline,
                                decorationColor: AppColors.indigo,
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
