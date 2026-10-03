import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';

/// `/about`: about, privacy, independence, change code, operator login.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsProvider);

    Widget section(String heading, String body) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(heading, style: theme.textTheme.titleMedium),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(body, style: theme.textTheme.bodyLarge),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l10n.commonBack,
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/'),
        ),
        title: Text(l10n.aboutTitle),
      ),
      body: PinnedBottomLayout(
        children: [
          section(l10n.aboutHeading, l10n.aboutBody),
          section(l10n.aboutPrivacyHeading, l10n.aboutPrivacyBody),
          section(l10n.aboutIndependenceHeading, l10n.aboutIndependenceBody),
          Semantics(
            header: true,
            child: Text(
              l10n.aboutGroupHeading,
              style: theme.textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            settings.groupLabel ?? l10n.aboutGroupNone,
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          SecondaryButton(
            key: const Key('about.changeCode'),
            label: l10n.aboutChangeCode,
            icon: Icons.group_rounded,
            onPressed: () => context.push('/invite'),
          ),
          const SizedBox(height: AppSpacing.xxl),
          const Divider(),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('about.operatorLogin'),
              onPressed: () => context.push('/admin/login'),
              icon: const Icon(Icons.lock_outline_rounded),
              label: Text(l10n.aboutOperatorLogin),
            ),
          ),
        ],
      ),
    );
  }
}
