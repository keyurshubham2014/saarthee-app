// V2-TASK-14 AC-1: status / severity / filter chips — icon + word for
// every value, en + gu, 1.0× + 2.0×, with and without motion.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/theme/icons.dart';
import 'package:saarthee/core/theme/tokens.dart';
import 'package:saarthee/core/widgets/widgets.dart';

import '../helpers/component_matrix.dart';

void main() {
  componentMatrix(
    'StatusChip × all statuses',
    (l10n) => Wrap(
      children: [for (final s in IssueStatus.values) StatusChip(status: s)],
    ),
    check: (t, l10n) async {
      final words = <String>{};
      for (final s in IssueStatus.values) {
        final chip = find.byKey(ValueKey('statusChip.${s.name}'));
        final word = issueStatusLabel(l10n, s);
        words.add(word);
        expect(
          find.descendant(of: chip, matching: find.text(word)),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: chip,
            matching: find.byIcon(IssueStatusStyle.of(s).icon),
          ),
          findsOneWidget,
          reason: '${s.name} has an icon',
        );
        expectSemantics(word);
      }
      expect(words, hasLength(7), reason: '7 distinct status words');
    },
  );

  componentMatrix(
    'SeverityChip × 4 severities',
    (l10n) => Wrap(
      children: [
        for (final s in AlertSeverity.values) SeverityChip(severity: s),
      ],
    ),
    check: (t, l10n) async {
      for (final s in AlertSeverity.values) {
        final chip = find.byKey(ValueKey('severityChip.${s.name}'));
        expect(
          find.descendant(
            of: chip,
            matching: find.text(alertSeverityLabel(l10n, s)),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: chip,
            matching: find.byIcon(AlertSeverityStyle.of(s).icon),
          ),
          findsOneWidget,
        );
        expectSemantics(alertSeverityLabel(l10n, s));
      }
    },
  );

  componentMatrix(
    'AppFilterChip selected + unselected, OverdueTag',
    (l10n) => Wrap(
      children: [
        AppFilterChip(
          label: l10n.statusReported,
          selected: true,
          onSelected: (_) {},
        ),
        AppFilterChip(
          label: l10n.statusVerified,
          selected: false,
          onSelected: (_) {},
          icon: SaartheeIcons.check,
        ),
        const OverdueTag(),
      ],
    ),
    check: (t, l10n) async {
      expect(find.text(l10n.statusReported), findsOneWidget);
      expect(find.text(l10n.statusVerified), findsOneWidget);
      expect(find.byIcon(SaartheeIcons.check), findsWidgets);
    },
  );
}
