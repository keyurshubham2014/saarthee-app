import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:saarthee/app.dart';
import 'package:saarthee/core/motion/haptics.dart';
import 'package:saarthee/core/settings/app_settings.dart';
import 'package:saarthee/core/settings/preference_sync.dart';
import 'package:saarthee/features/auth/application/ensure_signed_in.dart';
import 'package:saarthee/features/auth/auth_routes.dart';

import '../helpers/app.dart';
import '../helpers/fake_haptics.dart';
import '../helpers/motion.dart';

/// Test screen with an account-only action ("Follow", AC-1) and local state
/// (a counter) that must survive the sign-in round trip.
class FollowHarness extends ConsumerStatefulWidget {
  const FollowHarness({super.key});

  @override
  ConsumerState<FollowHarness> createState() => FollowHarnessState();
}

class FollowHarnessState extends ConsumerState<FollowHarness> {
  int typed = 0;
  int followed = 0;
  bool? lastResult;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        Text('typed:$typed followed:$followed', key: const Key('h.state')),
        TextButton(
          key: const Key('h.type'),
          onPressed: () => setState(() => typed++),
          child: const SizedBox.square(dimension: 48),
        ),
        TextButton(
          key: const Key('h.follow'),
          onPressed: () async {
            final ok = await ensureSignedIn(
              context,
              ref,
              reason: SignInReason.follow,
            );
            setState(() {
              lastResult = ok;
              if (ok) followed++;
            });
          },
          child: const SizedBox.square(dimension: 48),
        ),
      ],
    ),
  );
}

/// Pumps the real app shell (theme, l10n, motion) with a router holding the
/// harness at `/` and the TASK-04 sign-in routes.
Future<(ProviderContainer, GoRouter)> pumpAuthHarness(
  WidgetTester tester, {
  required List overrides,
  Widget home = const FollowHarness(),
  String initial = '/',
  List<RouteBase> extraRoutes = const [],
}) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final prefs = await testPrefs(onboardedPrefs());
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(path: '/', builder: (_, _) => home),
      ...authRoutes,
      ...extraRoutes,
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        saartheeHapticsProvider.overrideWithValue(FakeSaartheeHaptics()),
        preferenceSyncProvider.overrideWithValue(FakePreferenceSync()),
        ...overrides,
      ],
      child: SaartheeApp(router: router, showLaunch: false),
    ),
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(SaartheeApp)),
  );
  return (container, router);
}
