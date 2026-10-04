import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';

/// `/onboarding/intro`: mark, wordmark, tagline, three benefit rows and the
/// independence line.
class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    final text = Theme.of(context).textTheme;
    Widget benefit(IconData icon, String label) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: AppSpacing.categoryBadge,
            height: AppSpacing.categoryBadge,
            decoration: BoxDecoration(
              color: c.primaryContainer,
              borderRadius: AppRadii.controlRadius,
            ),
            child: Icon(icon, color: c.onPrimaryContainer),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(child: Text(label, style: text.bodyLarge)),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l10n.commonBack,
          icon: const Icon(SaartheeIcons.back),
          onPressed: () => context.pop(),
        ),
      ),
      body: PinnedBottomLayout(
        bottom: [
          PrimaryButton(
            key: const Key('onboarding.intro.continue'),
            label: l10n.commonContinue,
            pinned: true,
            onPressed: () => context.push('/onboarding/ward'),
          ),
        ],
        children: [
          const Center(child: BrandMark(size: 72)),
          const SizedBox(height: AppSpacing.s16),
          const Wordmark(),
          const SizedBox(height: AppSpacing.s8),
          Text(
            l10n.introTagline,
            textAlign: TextAlign.center,
            style: text.titleLarge,
          ),
          const SizedBox(height: AppSpacing.s32),
          benefit(SaartheeIcons.camera, l10n.introBenefitReport),
          benefit(SaartheeIcons.taskAlt, l10n.introBenefitFollow),
          benefit(SaartheeIcons.notifications, l10n.introBenefitAlerts),
          const SizedBox(height: AppSpacing.s8),
          const IndependenceNotice(),
        ],
      ),
    );
  }
}
