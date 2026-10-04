// W-08-07 (AC-16, AC-18): in-app alert banner — slide-in, one Critical pulse (no loop), auto-hide,
// announcement, reduced motion; plus the controller rules (Critical wins, new ids in the active list).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/config/timings.dart';
import 'package:saarthee/core/theme/motion.dart';
import 'package:saarthee/core/theme/tokens.dart';
import 'package:saarthee/core/widgets/alerts/in_app_alert_banner.dart';
import 'package:saarthee/features/alerts/application/in_app_alert_controller.dart';
import 'package:saarthee/features/alerts/data/alert_models.dart';
import 'package:saarthee/core/settings/app_settings.dart';

import '../helpers/motion.dart';
import 'alert_fakes.dart';

final _key = GlobalKey<InAppAlertBannerState>();

Future<List<String>> _pump(
  WidgetTester t,
  AlertSeverity s, {
  bool reduced = false,
  VoidCallback? onDismissed,
}) async {
  final announced = <String>[];
  t.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(
    SystemChannels.accessibility,
    (m) async {
      final data = (m as Map)['data'] as Map?;
      if (data?['message'] is String) announced.add(data!['message'] as String);
      return null;
    },
  );
  await pumpMotion(
    t,
    Stack(
      children: [
        Positioned(
          top: 56,
          left: 0,
          right: 0,
          child: InAppAlertBanner(
            key: _key,
            severity: s,
            title: 'Severe heat today',
            onView: () {},
            onDismissed: onDismissed ?? () {},
          ),
        ),
      ],
    ),
    reduced: reduced,
  );
  return announced;
}

/// Real-ish frames (16 ms) so animation completion callbacks run between them.
Future<void> _frames(WidgetTester t, Duration total) async {
  for (
    var e = Duration.zero;
    e < total;
    e += const Duration(milliseconds: 16)
  ) {
    await t.pump(const Duration(milliseconds: 16));
  }
}

double _dy(WidgetTester t) => t
    .widget<FractionalTranslation>(
      find.byKey(const ValueKey('inAppAlertSlide')),
    )
    .translation
    .dy;

void main() {
  testWidgets(
    'Critical: slides in with springIn, pulses exactly once, then no scheduled frames',
    (t) async {
      final announced = await _pump(t, AlertSeverity.critical);
      expect(_dy(t), lessThan(0));
      await t.pump(SaartheeMotion.springIn.duration);
      expect(_dy(t), closeTo(0, 0.001));
      final state = _key.currentState!;
      await _frames(t, SaartheeMotion.long.duration ~/ 2);
      expect(state.pulse.value, greaterThan(0));
      await _frames(t, SaartheeMotion.long.duration * 2);
      expect(state.pulse.value, 0);
      expect(state.pulse.isAnimating, isFalse);
      expect(t.binding.hasScheduledFrame, isFalse);
      expect(announced, contains('New critical alert: Severe heat today'));
      // Critical stays until dismissed.
      await t.pump(AppTimings.alertBannerAutoHide * 2);
      expect(find.text('Severe heat today'), findsOneWidget);
      expect(
        t
            .widget<Container>(
              find.byKey(const ValueKey('severityBanner.critical')),
            )
            .decoration,
        isA<BoxDecoration>(),
      );
    },
  );

  testWidgets(
    'Info hides by itself after the timeout and slides up over medium',
    (t) async {
      var dismissed = 0;
      final announced = await _pump(
        t,
        AlertSeverity.info,
        onDismissed: () => dismissed++,
      );
      await t.pump(SaartheeMotion.springIn.duration);
      expect(_key.currentState!.pulse.value, 0);
      await t.pump(AppTimings.alertBannerAutoHide);
      await _frames(t, SaartheeMotion.medium.duration * 2);
      expect(dismissed, 1);
      expect(announced, contains('New alert: Severe heat today'));
    },
  );

  testWidgets('reduced motion: at rest after one pump, no pulse', (t) async {
    await _pump(t, AlertSeverity.critical, reduced: true);
    await t.pump();
    expect(_dy(t), closeTo(0, 0.001));
    expect(_key.currentState!.slide.value, 1);
    await t.pump(SaartheeMotion.long.duration);
    expect(_key.currentState!.pulse.isAnimating, isFalse);
    expect(_key.currentState!.pulse.value, 0);
  });

  test('controller: Critical is not replaced by Info; new ids after the first load raise a banner', () async {
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(await testPrefs()),
      ],
    );
    addTearDown(c.dispose);
    final n = c.read(inAppAlertProvider.notifier);
    final info = Alert.fromJson(alertJson(id: 'i1'));
    final crit = Alert.fromJson(alertJson(id: 'c1', severity: 'critical'));
    n.onActiveList([info]);
    expect(c.read(inAppAlertProvider), isNull);
    n.onActiveList([info, crit]);
    expect(c.read(inAppAlertProvider)?.id, 'c1');
    n.offer(Alert.fromJson(alertJson(id: 'i2')));
    expect(c.read(inAppAlertProvider)?.id, 'c1');
    n.clear('c1');
    n.offer(Alert.fromJson(alertJson(id: 'i2')));
    expect(c.read(inAppAlertProvider)?.id, 'i2');
  });

  test('the Critical pulse never loops (no repeat() in the banner)', () {
    final src = File('lib/core/widgets/alerts/in_app_alert_banner.dart')
        .readAsStringSync();
    expect(src.contains('.repeat('), isFalse);
  });
}
