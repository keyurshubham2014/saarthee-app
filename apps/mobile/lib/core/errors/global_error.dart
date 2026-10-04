import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/icons.dart';
import '../theme/tokens.dart';
import '../widgets/widgets.dart';

/// Generic "Something went wrong" view with "Go home" (02 §9.1). Shown for
/// uncaught errors in release builds. Never touches local storage.
class GlobalErrorView extends StatelessWidget {
  const GlobalErrorView({super.key, required this.onGoHome});

  final VoidCallback onGoHome;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      body: PinnedBottomLayout(
        bottom: [
          PrimaryButton(
            key: const Key('globalError.goHome'),
            label: l10n.commonGoHome,
            onPressed: onGoHome,
          ),
        ],
        children: [
          const SizedBox(height: AppSpacing.s40),
          Icon(
            SaartheeIcons.errorOutline,
            size: AppSpacing.touchTarget,
            color: SaartheeColors.of(context).error,
          ),
          const SizedBox(height: AppSpacing.s16),
          Semantics(
            header: true,
            liveRegion: true,
            child: Text(
              l10n.globalErrorTitle,
              style: theme.textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          Text(l10n.globalErrorBody, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }
}
