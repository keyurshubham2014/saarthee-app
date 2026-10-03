import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';

/// Confirmation layout shared by "Report recorded" and verify "Thank you".
class ConfirmationScreen extends StatelessWidget {
  const ConfirmationScreen({
    super.key,
    required this.title,
    required this.body,
    this.buttonKey,
    this.onDone,
  });

  final String title;
  final String body;
  final Key? buttonKey;

  /// Runs before returning Home (e.g. ending the verify session).
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: PinnedBottomLayout(
          bottom: [
            PrimaryButton(
              key: buttonKey,
              label: l10n.commonDone,
              onPressed: () {
                onDone?.call();
                context.go('/');
              },
            ),
          ],
          children: [
            const SizedBox(height: AppSpacing.xxxl),
            const Align(
              alignment: Alignment.centerLeft,
              child: CircleAvatar(
                radius: 32,
                backgroundColor: AppColors.fixedTint,
                child: Icon(
                  Icons.check_rounded,
                  size: 40,
                  color: AppColors.fixed,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Semantics(
              header: true,
              liveRegion: true,
              child: Text(title, style: theme.textTheme.headlineMedium),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(body, style: theme.textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}

/// `/report/done` (02 §4.10).
class ReportDoneScreen extends StatelessWidget {
  const ReportDoneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ConfirmationScreen(
      buttonKey: const Key('report.done'),
      title: l10n.reportDoneTitle,
      body: l10n.reportDoneBody,
    );
  }
}
