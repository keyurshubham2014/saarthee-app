// W-08-01 (AC-9): SeverityBanner / AlertCard for 4 severities; W-08-02: validity formatter (gu + en, IST).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:saarthee/core/l10n/app_localizations.dart';
import 'package:saarthee/core/theme/tokens.dart';
import 'package:saarthee/core/widgets/alerts/alert_widgets.dart';
import 'package:saarthee/core/widgets/alerts/validity_format.dart';

import '../helpers/motion.dart';

void main() {
  testWidgets(
    'severity banner: icon + word, Critical solid with white text, others tinted',
    (t) async {
      await pumpMotion(
        t,
        Column(
          children: [
            for (final s in AlertSeverity.values)
              SeverityBanner(severity: s, message: 'Title ${s.name}'),
          ],
        ),
      );
      for (final (s, word) in [
        (AlertSeverity.info, 'Info'),
        (AlertSeverity.advisory, 'Advisory'),
        (AlertSeverity.warning, 'Warning'),
        (AlertSeverity.critical, 'Critical'),
      ]) {
        final banner = find.byKey(ValueKey('severityBanner.${s.name}'));
        expect(
          find.descendant(of: banner, matching: find.text(word)),
          findsOneWidget,
        );
        final icon = t.widget<Icon>(
          find.descendant(of: banner, matching: find.byType(Icon)),
        );
        expect(icon.icon, AlertSeverityStyle.of(s).icon);
        final box = t.widget<Container>(banner).decoration! as BoxDecoration;
        final tone = AlertSeverityStyle.of(s);
        expect(
          box.color,
          s == AlertSeverity.critical ? tone.solid : tone.tint,
          reason: s.name,
        );
        expect(box.borderRadius, AppRadii.cardRadius);
        if (s == AlertSeverity.critical) {
          final title = t.widget<Text>(
            find.descendant(of: banner, matching: find.text('Title critical')),
          );
          expect(title.style?.color, NeemFixed.white);
        }
      }
    },
  );

  testWidgets(
    'ended banner is grey; source line and independence footer render',
    (t) async {
      await pumpMotion(
        t,
        const Column(
          children: [
            SeverityBanner(
              severity: AlertSeverity.critical,
              ended: true,
              message: 'This alert has ended.',
            ),
            SourceLine(source: 'IMD Ahmedabad'),
            IndependenceFooter(),
          ],
        ),
        locale: const Locale('gu'),
      );
      expect(
        find.byKey(const ValueKey('severityBanner.critical.ended')),
        findsOneWidget,
      );
      expect(find.textContaining('IMD Ahmedabad'), findsOneWidget);
      expect(
        find.text(
          'નાગરિકોની સ્વતંત્ર એપ. AMC દ્વારા ચલાવાતી કે તેની સાથે જોડાયેલી નથી.',
        ),
        findsOneWidget,
      );
    },
  );

  group('validity formatter (W-08-02)', () {
    setUpAll(() async {
      await initializeDateFormatting('en');
      await initializeDateFormatting('gu');
    });
    DateTime ist(String s) => DateTime.parse('$s+05:30');

    test(
      'same day today, until, ranges — in IST whatever the input zone',
      () async {
        final en = await AppLocalizations.delegate.load(const Locale('en'));
        final gu = await AppLocalizations.delegate.load(const Locale('gu'));
        final now = ist('2030-01-10T09:00:00');
        expect(
          formatAlertValidity(
            en,
            'en',
            ist('2030-01-10T10:00:00'),
            ist('2030-01-10T16:00:00'),
            now: now,
          ),
          'Today 10:00–16:00',
        );
        expect(
          formatAlertValidity(
            en,
            'en',
            ist('2030-01-10T08:00:00'),
            ist('2030-01-12T18:00:00'),
            now: now,
          ),
          'Until Sat 12 Jan, 18:00',
        );
        expect(
          formatAlertValidity(
            en,
            'en',
            ist('2030-01-11T10:00:00'),
            ist('2030-01-11T16:00:00'),
            now: now,
          ),
          'Fri 11 Jan, 10:00 – 16:00',
        );
        expect(
          formatAlertValidity(
            en,
            'en',
            ist('2030-01-11T10:00:00'),
            ist('2030-01-13T16:00:00'),
            now: now,
          ),
          'Fri 11 Jan, 10:00 – Sun 13 Jan, 16:00',
        );
        final g = formatAlertValidity(
          gu,
          'gu',
          ist('2030-01-10T10:00:00'),
          ist('2030-01-10T16:00:00'),
          now: now,
        );
        expect(g, startsWith('આજે'));
        expect(
          formatAlertValidity(
            gu,
            'gu',
            ist('2030-01-10T08:00:00'),
            ist('2030-01-12T18:00:00'),
            now: now,
          ),
          endsWith('સુધી'),
        );
      },
    );
  });
}
