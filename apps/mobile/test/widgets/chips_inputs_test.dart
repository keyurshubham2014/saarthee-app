// T-03-06 inputs + ErrorSummary, T-03-07 status/severity chips (en + gu).
import 'package:flutter/material.dart' hide ErrorSummary;
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/theme/tokens.dart';
import 'package:saarthee/core/widgets/widgets.dart';

import '../helpers/motion.dart';

const _statusEn = {
  IssueStatus.reported: 'Reported',
  IssueStatus.acknowledged: 'Acknowledged',
  IssueStatus.inProgress: 'In progress',
  IssueStatus.verified: 'Verified',
  IssueStatus.reopened: 'Reopened',
  IssueStatus.rejected: 'Not accepted',
};
const _statusGu = {
  IssueStatus.reported: 'નોંધાઈ',
  IssueStatus.inProgress: 'કામ ચાલુ',
  IssueStatus.verified: 'ચકાસાયેલ',
};
const _severityEn = {
  AlertSeverity.info: 'Info',
  AlertSeverity.advisory: 'Advisory',
  AlertSeverity.warning: 'Warning',
  AlertSeverity.critical: 'Critical',
};

void main() {
  group('T-03-07 chips', () {
    testWidgets('every status shows its icon and English word', (t) async {
      await pumpMotion(
        t,
        Wrap(
          children: [
            for (final s in IssueStatus.values) StatusChip(status: s),
          ],
        ),
      );
      for (final s in IssueStatus.values) {
        final chip = find.byKey(ValueKey('statusChip.${s.name}'));
        expect(chip, findsOneWidget, reason: s.name);
        final icon = find.descendant(of: chip, matching: find.byType(Icon));
        expect(
          t.widget<Icon>(icon).icon,
          IssueStatusStyle.of(s).icon,
          reason: s.name,
        );
      }
      _statusEn.forEach((s, w) => expect(find.text(w), findsWidgets));
    });

    testWidgets('status words switch to Gujarati', (t) async {
      await pumpMotion(
        t,
        Wrap(
          children: [
            for (final s in _statusGu.keys) StatusChip(status: s),
          ],
        ),
        locale: const Locale('gu'),
      );
      _statusGu.forEach((s, w) => expect(find.text(w), findsOneWidget));
    });

    testWidgets('every severity shows icon + word', (t) async {
      await pumpMotion(
        t,
        Wrap(
          children: [
            for (final s in AlertSeverity.values) SeverityChip(severity: s),
          ],
        ),
      );
      _severityEn.forEach((s, w) {
        final chip = find.byKey(ValueKey('severityChip.${s.name}'));
        expect(
          find.descendant(of: chip, matching: find.text(w)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: chip, matching: find.byType(Icon)),
          findsOneWidget,
        );
      });
    });
  });

  group('T-03-06 inputs', () {
    testWidgets('optional suffix, helper and error row', (t) async {
      await pumpMotion(
        t,
        const LabeledTextField(
          label: 'Landmark',
          optional: true,
          helper: 'Near the temple',
          error: 'Too long',
        ),
      );
      expect(find.textContaining('Landmark'), findsWidgets);
      expect(find.textContaining('(optional)'), findsOneWidget);
      expect(find.text('Too long'), findsOneWidget);
      expect(find.byType(InlineFieldError), findsOneWidget);
    });

    testWidgets('ErrorSummary takes focus and items are tappable', (
      t,
    ) async {
      var tapped = 0;
      await pumpMotion(
        t,
        ErrorSummary(
          items: [ErrorSummaryItem('Enter a name', onTap: () => tapped++)],
        ),
      );
      await t.pump();
      expect(find.text('There is a problem'), findsOneWidget);
      final focus = FocusManager.instance.primaryFocus;
      expect(focus, isNotNull);
      expect(
        find.ancestor(of: find.text('There is a problem'), matching: find.byType(Focus)),
        findsWidgets,
      );
      await t.tap(find.text('Enter a name'));
      expect(tapped, 1);
    });
  });
}
