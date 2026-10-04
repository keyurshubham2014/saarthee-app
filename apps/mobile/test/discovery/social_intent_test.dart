// TASK-14 (emulator): an action resumed after sign-in sets the intended state;
// it never toggles back what the refreshed detail already shows.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/features/discovery/data/discovery_api.dart';
import 'package:saarthee/features/discovery/application/social_controller.dart';

import 'fakes.dart';

void main() {
  test('setFollow / setMeToo are idempotent', () async {
    final api = FakeDiscoveryApi();
    final c = ProviderContainer(
      overrides: [discoveryApiProvider.overrideWithValue(api)],
    );
    addTearDown(c.dispose);
    final sub = c.listen(socialProvider('i1'), (_, _) {});
    addTearDown(sub.close);
    final social = c.read(socialProvider('i1').notifier);

    expect(await social.setFollow(true), isTrue);
    expect(await social.setFollow(true), isTrue);
    expect(api.calls.where((x) => x.startsWith('follow')), ['follow i1 true']);
    expect(c.read(socialProvider('i1')).isFollowing, isTrue);

    expect(await social.setMeToo(true), isTrue);
    expect(await social.setMeToo(true), isTrue);
    expect(api.calls.where((x) => x.startsWith('meToo')), ['meToo i1 true']);
    expect(c.read(socialProvider('i1')).hasMeToo, isTrue);
  });
}
