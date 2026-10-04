import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';

/// `/about` (v2): wordmark, version, the independence line in both
/// languages, the independence statement, the name origin, the grievance
/// contact and the operator login link.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final email = AppConfig.grievanceEmail;
    Widget para(String s, {Locale? locale}) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s16),
      child: Text(s, style: text.bodyLarge, locale: locale),
    );
    return Scaffold(
      appBar: SaartheeAppBar(title: l10n.aboutTitle),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        children: [
          const SizedBox(height: AppSpacing.s8),
          const Center(child: BrandMark(size: 64)),
          const SizedBox(height: AppSpacing.s12),
          const Wordmark(),
          Text(
            l10n.aboutVersion(AppConfig.appVersion),
            textAlign: TextAlign.center,
            style: text.bodySmall,
          ),
          const SizedBox(height: AppSpacing.s24),
          Container(
            key: const Key('about.independence'),
            padding: const EdgeInsets.all(AppSpacing.s16),
            decoration: BoxDecoration(
              color: SaartheeColors.of(context).infoTint,
              borderRadius: AppRadii.cardRadius,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.aboutIndependenceLineEn,
                  style: text.titleMedium,
                  locale: const Locale('en'),
                ),
                const SizedBox(height: AppSpacing.s4),
                Text(
                  l10n.aboutIndependenceLineGu,
                  style: text.titleMedium,
                  locale: const Locale('gu'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s24),
          para(l10n.aboutIndependenceStatement),
          para(l10n.aboutNameOrigin),
          para(
            email.isEmpty
                ? l10n.aboutGrievancePending
                : l10n.aboutGrievance(email),
          ),
          const Divider(),
          ListRow(
            key: const Key('about.licenses'),
            leading: const Icon(SaartheeIcons.description),
            title: l10n.aboutLicenses,
            onTap: () => showLicensePage(
              context: context,
              applicationName: l10n.appTitle,
              applicationVersion: AppConfig.appVersion,
            ),
          ),
          ListRow(
            key: const Key('about.operatorLogin'),
            leading: const Icon(SaartheeIcons.lock),
            title: l10n.aboutOperatorLogin,
            onTap: () => context.push('/admin/login'),
          ),
        ],
      ),
    );
  }
}
