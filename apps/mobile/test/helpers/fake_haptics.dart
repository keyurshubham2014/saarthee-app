import 'package:saarthee/core/motion/haptics.dart';

/// Records haptic calls in order (`light`, `selection`, `success`) so tests
/// of this and later tasks can assert feedback without a platform channel.
class FakeSaartheeHaptics extends SaartheeHaptics {
  FakeSaartheeHaptics();

  final List<String> calls = [];

  @override
  Future<void> light() async => calls.add('light');

  @override
  Future<void> selection() async => calls.add('selection');

  @override
  Future<void> success() async => calls.add('success');
}
