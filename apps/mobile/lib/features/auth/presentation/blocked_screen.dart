import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';

/// `/sign-in/blocked` (AC-4): under-18 answer. Firebase is already signed
/// out and nothing was stored; "Back to browsing" ends the sign-in flow.
class BlockedScreen extends StatelessWidget {
  const BlockedScreen({super.key});

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final c = SaartheeColors.of(context);
    return Scaffold(
      appBar: SaartheeAppBar(
        title: l10n.authBlockedTitle,
        onBack: () => _back(context),
      ),
      body: PinnedBottomLayout(
        bottom: [
          PrimaryButton(
            key: const Key('blocked.back'),
            label: l10n.authBackToBrowsing,
            pinned: true,
            onPressed: () => _back(context),
          ),
        ],
        children: [
          const SizedBox(height: AppSpacing.s24),
          Icon(
            SaartheeIcons.personOff,
            size: AppSpacing.emptyIcon,
            color: c.textSecondary,
          ),
          const SizedBox(height: AppSpacing.s16),
          Text(
            l10n.authBlockedBody,
            key: const Key('blocked.body'),
            style: text.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
