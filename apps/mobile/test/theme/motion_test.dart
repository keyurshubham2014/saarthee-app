// T-03-21 SaartheeMotion tokens, reduced scheme and reducedMotionProvider.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/settings/app_settings.dart';
import 'package:saarthee/core/settings/motion_preference.dart';
import 'package:saarthee/core/theme/motion.dart';

import '../helpers/motion.dart';

const _ms = Duration(milliseconds: 1);

void main() {
  group('T-03-21 tokens equal DS §6', () {
    test('durations and curves', () {
      expect(SaartheeMotion.instant.duration, _ms * 100);
      expect(SaartheeMotion.instant.curve, Curves.easeOut);
      expect(SaartheeMotion.short.duration, _ms * 180);
      expect(SaartheeMotion.short.curve, const Cubic(0.2, 0, 0, 1));
      expect(SaartheeMotion.medium.duration, _ms * 280);
      expect(SaartheeMotion.medium.curve, const Cubic(0.2, 0, 0, 1));
      expect(SaartheeMotion.springIn.duration, _ms * 380);
      expect(SaartheeMotion.springIn.curve, const Cubic(0.34, 1.35, 0.64, 1));
      expect(SaartheeMotion.long.duration, _ms * 450);
      expect(SaartheeMotion.long.curve, const Cubic(0.05, 0.7, 0.1, 1));
      expect(SaartheeMotion.drawCheck.duration, _ms * 450);
      expect(SaartheeMotion.drawCheckDelay, _ms * 150);
      expect(SaartheeMotion.countUp.duration, _ms * 600);
      expect(SaartheeMotion.countUp.curve, Curves.easeOutCubic);
    });

    test('staggers, offsets and scales', () {
      expect(SaartheeMotion.stagger, _ms * 60);
      expect(SaartheeMotion.tileStagger, _ms * 35);
      expect(SaartheeMotion.staggerMaxItems, 6);
      expect(SaartheeMotion.mapPinStagger, _ms * 30);
      expect(SaartheeMotion.mapPinMaxAnimated, 20);
      expect(SaartheeMotion.riseOffset, 14);
      expect(SaartheeMotion.pressScale, 0.97);
      expect(SaartheeMotion.shimmerPeriod, _ms * 1200);
      expect(SaartheeMotion.launchMarkScaleFrom, 0.92);
      expect(SaartheeMotion.selectSpringScale, 1.02);
      expect(SaartheeMotion.toastHold, const Duration(seconds: 4));
    });

    test('springIn overshoot stays ≤ 6%', () {
      var peak = 0.0;
      for (var i = 0; i <= 1000; i++) {
        final v = SaartheeMotion.springIn.curve.transform(i / 1000);
        if (v > peak) peak = v;
      }
      expect(peak, lessThanOrEqualTo(1.06));
    });
  });

  group('T-03-21 reduced scheme', () {
    const r = SaartheeMotion.reduced;
    test('transforms, staggers, draws and counts go to zero', () {
      expect(r.isReduced, isTrue);
      expect(r.transforms, isFalse);
      expect(r.springIn.duration, Duration.zero);
      expect(r.stagger, Duration.zero);
      expect(r.tileStagger, Duration.zero);
      expect(r.drawCheck.duration, Duration.zero);
      expect(r.drawCheckDelay, Duration.zero);
      expect(r.countUp.duration, Duration.zero);
      expect(r.pressScale, 1);
      expect(r.riseOffset, 0);
      expect(r.shimmer, isFalse);
    });

    test('page, tab, sheet transitions become a 100 ms fade', () {
      expect(r.medium.duration, _ms * 100);
      expect(r.crossFade.duration, _ms * 100);
      expect(r.long.duration, _ms * 100);
    });

    test('full scheme keeps the tokens', () {
      const f = SaartheeMotion.full;
      expect(f.medium, SaartheeMotion.medium);
      expect(f.stagger, SaartheeMotion.stagger);
      expect(f.pressScale, 0.97);
    });
  });

  group('T-03-21 reducedMotionProvider truth table', () {
    for (final (system, enabled, expected) in [
      (false, true, false),
      (true, true, true),
      (false, false, true),
      (true, false, true),
    ]) {
      test('system=$system animationsEnabled=$enabled → $expected', () async {
        final prefs = await testPrefs({PrefKeys.animationsEnabled: enabled});
        final c = ProviderContainer(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        );
        addTearDown(c.dispose);
        c.read(systemDisableAnimationsProvider.notifier).set(system);
        expect(c.read(reducedMotionProvider), expected);
      });
    }

    test('setEnabled persists v2.animationsEnabled', () async {
      final prefs = await testPrefs();
      final c = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(c.dispose);
      expect(c.read(motionPreferenceProvider), isTrue);
      await c.read(motionPreferenceProvider.notifier).setEnabled(false);
      expect(prefs.getBool(PrefKeys.animationsEnabled), isFalse);
      expect(c.read(reducedMotionProvider), isTrue);
    });
  });

  group('T-03-21 SaartheeMotion.of follows the provider', () {
    Future<SaartheeMotionScheme> resolve(
      WidgetTester tester, {
      bool? reduced,
      bool disableAnimations = false,
    }) async {
      late SaartheeMotionScheme scheme;
      await pumpMotion(
        tester,
        Builder(
          builder: (context) {
            scheme = SaartheeMotion.of(context);
            return const SizedBox();
          },
        ),
        reduced: reduced,
        disableAnimations: disableAnimations,
      );
      await tester.pump();
      return scheme;
    }

    testWidgets('full by default', (tester) async {
      expect((await resolve(tester)).isReduced, isFalse);
    });
    testWidgets('reduced when the provider is true', (tester) async {
      expect((await resolve(tester, reduced: true)).isReduced, isTrue);
    });
    testWidgets('reduced under system Remove animations', (tester) async {
      final s = await resolve(tester, disableAnimations: true);
      expect(s.isReduced, isTrue);
    });
  });
}
