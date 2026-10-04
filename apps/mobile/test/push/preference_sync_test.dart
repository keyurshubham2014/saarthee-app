// T-04-21 (AC-7): AccountPreferenceSync — language / ward change → one
// PATCH /me, topic switch (old unsubscribed, new subscribed), POST /devices.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/motion/haptics.dart';
import 'package:saarthee/core/push/push_messaging.dart';
import 'package:saarthee/core/push/push_registrar.dart';
import 'package:saarthee/core/settings/app_settings.dart';
import 'package:saarthee/core/settings/locale_controller.dart';
import 'package:saarthee/core/settings/preference_sync.dart';
import 'package:saarthee/core/wards/ward_providers.dart';
import 'package:saarthee/features/auth/application/session_controller.dart';
import 'package:saarthee/features/me/application/account_preference_sync.dart';

import '../auth/fakes.dart';
import '../helpers/app.dart';
import '../helpers/fake_haptics.dart';
import '../helpers/fake_wards.dart';
import '../helpers/motion.dart';

Future<
  (ProviderContainer, FakeAccountApi, LocalOnlyPushMessaging, RecordingAdapter)
>
setUpSync({bool signedIn = true, bool notifications = true}) async {
  final prefs = await testPrefs({
    ...onboardedPrefs(language: 'en'),
    PushRegistrar.enabledKey: true,
    PushRegistrar.topicsKey: ['city_all__en'],
  });
  final api = FakeAccountApi()..me = sampleMe(notifications: notifications);
  final push = LocalOnlyPushMessaging();
  final http = RecordingAdapter();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      saartheeHapticsProvider.overrideWithValue(FakeSaartheeHaptics()),
      preferenceSyncProvider.overrideWith(AccountPreferenceSync.new),
      ...authOverrides(
        gateway: FakeAuthGateway(),
        api: api,
        push: push,
        http: http,
        signedIn: signedIn,
      ),
    ],
  );
  addTearDown(container.dispose);
  await container.read(sessionProvider.notifier).ready;
  if (signedIn) container.read(sessionProvider.notifier).setMe(api.me);
  return (container, api, push, http);
}

List<Map> devicePosts(RecordingAdapter http) => [
  for (final r in http.requests)
    if (r.method == 'POST' && r.path == '/devices') r.body! as Map,
];

void main() {
  test(
    'language change: PATCH once, topics switch, device re-posted',
    () async {
      final (c, api, push, http) = await setUpSync();
      await c.read(localeProvider.notifier).setLanguage('gu');
      expect(api.patches, [
        {'language': 'gu'},
      ]);
      expect(push.unsubscribed, ['city_all__en']);
      expect(push.subscribed, ['city_all__gu']);
      final post = devicePosts(http).single;
      expect(post['language'], 'gu');
      expect(post['topics'], ['city_all__gu']);
      expect(http.requests.single.path, '/devices');
    },
  );

  test('home ward change: PATCH homeWardId, ward topic subscribed', () async {
    final (c, api, push, http) = await setUpSync();
    await c.read(homeWardProvider.notifier).set(paldi);
    expect(api.patches, [
      {'homeWardId': paldi.id},
    ]);
    expect(push.subscribed, ['ward_${paldi.number}__en']);
    expect(push.unsubscribed, isEmpty);
    expect(devicePosts(http).single['topics'], [
      'ward_${paldi.number}__en',
      'city_all__en',
    ]);
  });

  test('signed out: no PATCH, topics still switch', () async {
    final (c, api, push, http) = await setUpSync(signedIn: false);
    await c.read(localeProvider.notifier).setLanguage('gu');
    expect(api.patches, isEmpty);
    expect(push.subscribed, ['city_all__gu']);
    expect(devicePosts(http), hasLength(1));
  });

  test('withdrawn notifications consent → every topic unsubscribed', () async {
    final (c, _, push, http) = await setUpSync(notifications: false);
    await c.read(localeProvider.notifier).setLanguage('gu');
    expect(push.unsubscribed, ['city_all__en']);
    expect(push.subscribed, isEmpty);
    expect(devicePosts(http).single['topics'], isEmpty);
    expect(c.read(pushRegistrarProvider).topics, isEmpty);
  });
}
