import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/icons.dart';
import '../theme/tokens.dart';

/// Fatal configuration screen (V2 TASK-13 §5.4): shown instead of the app when
/// the build's `API_BASE_URL` is not allowed for its build mode (see
/// `apiBaseUrlIsAllowed`). Makes no network request and logs nothing.
class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (c) => AppLocalizations.of(c).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const ConfigErrorView(),
    );
  }
}

class ConfigErrorView extends StatelessWidget {
  const ConfigErrorView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = SaartheeColors.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.s40),
              Icon(
                SaartheeIcons.errorOutline,
                size: AppSpacing.touchTarget,
                color: colors.error,
              ),
              const SizedBox(height: AppSpacing.s16),
              Semantics(
                liveRegion: true,
                child: Text(
                  l10n.configErrorBody,
                  key: const Key('configError.body'),
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
