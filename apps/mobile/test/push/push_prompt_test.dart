// Home push soft prompt (TASK-04 §5.4): never at first launch; "Turn on"
// asks permission and subscribes; "Not now" hides it for good.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/push/push_messaging.dart';
import 'package:saarthee/core/push/push_registrar.dart';
import 'package:saarthee/features/me/presentation/push_prompt_card.dart';

import '../auth/fakes.dart';
import '../auth/harness.dart';

Widget _home() => const Scaffold(body: Column(children: [PushPromptCard()]));

void main() {
  testWidgets('hidden at first launch', (t) async {
    await pumpAuthHarness(
      t,
      home: _home(),
      overrides: authOverrides(
        gateway: FakeAuthGateway(),
        api: FakeAccountApi(),
      ),
    );
    expect(find.byKey(const Key('home.pushPrompt')), findsNothing);
  });

  testWidgets('second launch: Turn on subscribes and hides the card', (
    t,
  ) async {
    final push = LocalOnlyPushMessaging();
    final (c, _) = await pumpAuthHarness(
      t,
      home: _home(),
      extraPrefs: {PushRegistrar.launchesKey: 2},
      overrides: authOverrides(
        gateway: FakeAuthGateway(),
        api: FakeAccountApi(),
        push: push,
      ),
    );
    expect(find.text('Get alerts for Ahmedabad?'), findsOneWidget);
    await t.tap(find.byKey(const Key('home.pushPrompt.turnOn')));
    await t.pumpAndSettle();
    expect(push.subscribed, ['city_all__en']);
    expect(c.read(pushRegistrarProvider).enabled, isTrue);
    expect(find.byKey(const Key('home.pushPrompt')), findsNothing);
  });

  testWidgets('Not now hides it for good', (t) async {
    final push = LocalOnlyPushMessaging();
    final (c, _) = await pumpAuthHarness(
      t,
      home: _home(),
      extraPrefs: {PushRegistrar.launchesKey: 3},
      overrides: authOverrides(
        gateway: FakeAuthGateway(),
        api: FakeAccountApi(),
        push: push,
      ),
    );
    await t.tap(find.byKey(const Key('home.pushPrompt.notNow')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('home.pushPrompt')), findsNothing);
    expect(c.read(pushRegistrarProvider).shouldPrompt, isFalse);
    expect(push.subscribed, isEmpty);
  });
}
