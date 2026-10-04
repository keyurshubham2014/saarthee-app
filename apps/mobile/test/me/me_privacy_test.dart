// T-04-20 (AC-6, AC-8, AC-10): /me edit flow, /me/privacy toggles and
// export call the API fakes; the delete dialog requires "DELETE".
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:saarthee/features/auth/application/session_controller.dart';
import 'package:saarthee/features/me/application/me_controller.dart';
import 'package:saarthee/features/me/presentation/me_screen.dart';
import 'package:saarthee/features/me/presentation/privacy_screen.dart';

import '../auth/fakes.dart';
import '../auth/harness.dart';

final _routes = <RouteBase>[
  GoRoute(path: '/me/privacy', builder: (_, _) => const PrivacyScreen()),
  GoRoute(path: '/me/settings', builder: (_, _) => const SizedBox()),
];

bool _enabled(WidgetTester t, Key key) =>
    t.widget<TextButton>(find.byKey(key)).onPressed != null;

void main() {
  testWidgets('/me shows the masked phone and saves the display name', (
    t,
  ) async {
    final api = FakeAccountApi();
    await pumpAuthHarness(
      t,
      home: const MeScreen(),
      extraRoutes: _routes,
      overrides: authOverrides(
        gateway: FakeAuthGateway(),
        api: api,
        signedIn: true,
      ),
    );
    expect(find.text('+91 ••••• ••001'), findsOneWidget);
    await t.enterText(find.byKey(const Key('me.displayName')), 'x' * 41);
    await t.tap(find.byKey(const Key('me.displayName.save')));
    await t.pump();
    expect(find.text('Use 1 to 40 characters.'), findsOneWidget);
    expect(api.patches, isEmpty);

    await t.enterText(find.byKey(const Key('me.displayName')), 'Asha');
    await t.tap(find.byKey(const Key('me.displayName.save')));
    await t.pumpAndSettle();
    expect(api.patches, [
      {'displayName': 'Asha'},
    ]);
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('/me signed out shows the Sign in row', (t) async {
    await pumpAuthHarness(
      t,
      home: const MeScreen(),
      extraRoutes: _routes,
      overrides: authOverrides(
        gateway: FakeAuthGateway(),
        api: FakeAccountApi(),
      ),
    );
    expect(find.byKey(const Key('me.signIn')), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('privacy toggles, export and core fixed', (t) async {
    final api = FakeAccountApi();
    final (container, router) = await pumpAuthHarness(
      t,
      home: const MeScreen(),
      extraRoutes: _routes,
      overrides: authOverrides(
        gateway: FakeAuthGateway(),
        api: api,
        signedIn: true,
      ),
    );
    router.push('/me/privacy');
    await t.pumpAndSettle();
    expect(find.text('Needed for your account'), findsOneWidget);
    expect(find.byType(Switch), findsNWidgets(3));

    await t.tap(find.byKey(const Key('privacy.consent.notifications')));
    await t.pumpAndSettle();
    expect(api.calls, contains('consent(notifications,false)'));
    await t.tap(
      find.byKey(const Key('privacy.consent.share_with_representatives')),
    );
    await t.pumpAndSettle();
    expect(api.calls, contains('consent(share_with_representatives,true)'));

    await t.tap(find.byKey(const Key('privacy.download')));
    await t.pumpAndSettle();
    expect(api.calls, contains('export'));
    final sharer = container.read(fileSharerProvider) as FakeFileSharer;
    expect(sharer.shared.single, endsWith('.json'));
    expect(find.byKey(const Key('privacy.exportSheet')), findsNothing);
  });

  testWidgets('delete dialog requires DELETE, then signs out', (t) async {
    final api = FakeAccountApi();
    final (container, router) = await pumpAuthHarness(
      t,
      home: const MeScreen(),
      extraRoutes: _routes,
      overrides: authOverrides(
        gateway: FakeAuthGateway(),
        api: api,
        signedIn: true,
      ),
    );
    router.push('/me/privacy');
    await t.pumpAndSettle();
    await t.ensureVisible(find.byKey(const Key('privacy.delete')));
    await t.tap(find.byKey(const Key('privacy.delete')));
    await t.pumpAndSettle();
    expect(find.text('Delete your account?'), findsOneWidget);
    const confirm = Key('delete.confirmButton');
    expect(_enabled(t, confirm), isFalse);
    await t.enterText(find.byKey(const Key('delete.confirm')), 'delete');
    await t.pump();
    expect(_enabled(t, confirm), isFalse);
    await t.enterText(find.byKey(const Key('delete.confirm')), 'DELETE');
    await t.pump();
    expect(_enabled(t, confirm), isTrue);
    await t.tap(find.byKey(confirm));
    await t.pumpAndSettle();
    expect(api.calls, contains('delete'));
    expect(container.read(sessionProvider).signedIn, isFalse);
    expect(find.text('Your account was deleted.'), findsOneWidget);
    expect(find.byKey(const Key('me.signIn')), findsOneWidget);
    await t.pump(const Duration(seconds: 5));
  });
}
