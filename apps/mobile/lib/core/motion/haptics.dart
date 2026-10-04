import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Haptic feedback (DS §6). Follows the system haptics setting (the
/// platform ignores these calls when touch feedback is off), independent of
/// the in-app Animations switch. Tests override [saartheeHapticsProvider]
/// with `FakeSaartheeHaptics`.
class SaartheeHaptics {
  const SaartheeHaptics();

  /// Primary actions.
  Future<void> light() => HapticFeedback.lightImpact();

  /// Selecting a tile or option.
  Future<void> selection() => HapticFeedback.selectionClick();

  /// Success moments (report sent, toast with a check).
  Future<void> success() => HapticFeedback.mediumImpact();
}

final saartheeHapticsProvider = Provider<SaartheeHaptics>(
  (ref) => const SaartheeHaptics(),
);
