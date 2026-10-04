import 'core/theme/scroll_behavior.dart';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/analytics/event_queue.dart';
import 'core/l10n/app_localizations.dart';
import 'core/settings/locale_controller.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/motion.dart';
import 'core/theme/theme_mode.dart';
import 'features/launch/launch_gate.dart';
import 'router/app_router.dart';

class SaartheeApp extends ConsumerStatefulWidget {
  const SaartheeApp({super.key, this.router, this.showLaunch = true});

  /// Test override; defaults to [appRouterProvider].
  final GoRouter? router;
  final bool showLaunch;

  @override
  ConsumerState<SaartheeApp> createState() => _SaartheeAppState();
}

class _SaartheeAppState extends ConsumerState<SaartheeApp> {
  @override
  void initState() {
    super.initState();
    // Start the analytics queue timer.
    ref.read(eventQueueProvider);
  }

  @override
  Widget build(BuildContext context) {
    final router = widget.router ?? ref.watch(appRouterProvider);
    return MaterialApp.router(
      onGenerateTitle: (c) => AppLocalizations.of(c).appTitle,
      debugShowCheckedModeBanner: false,
      scrollBehavior: const SaartheeScrollBehavior(),
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      locale: ref.watch(localeProvider),
      routerConfig: router,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('gu'), Locale('en')],
      builder: (context, child) {
        final page = child ?? const SizedBox.shrink();
        return MotionScope(
          child: widget.showLaunch ? LaunchGate(child: page) : page,
        );
      },
    );
  }
}
