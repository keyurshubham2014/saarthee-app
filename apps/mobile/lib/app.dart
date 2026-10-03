import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/analytics/event_queue.dart';
import 'core/l10n/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'router/app_router.dart';
import 'router/deep_links.dart';

class SaartheeApp extends ConsumerStatefulWidget {
  const SaartheeApp({super.key});

  @override
  ConsumerState<SaartheeApp> createState() => _SaartheeAppState();
}

class _SaartheeAppState extends ConsumerState<SaartheeApp> {
  @override
  void initState() {
    super.initState();
    // Start the analytics queue timer and the deep-link listener.
    ref.read(eventQueueProvider);
    ref.read(deepLinkListenerProvider);
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      onGenerateTitle: (c) => AppLocalizations.of(c).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
