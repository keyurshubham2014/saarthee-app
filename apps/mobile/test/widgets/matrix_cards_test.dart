// V2-TASK-14 AC-1: list row, issue card, status timeline, alert card,
// representative row and category badge × 14 across the matrix.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/theme/icons.dart';
import 'package:saarthee/core/theme/tokens.dart';
import 'package:saarthee/core/widgets/widgets.dart';

import '../helpers/component_matrix.dart';

void main() {
  componentMatrix(
    'ListRow with subtitle and chevron',
    (l10n) => ListRow(
      title: l10n.commonNotifications,
      subtitle: l10n.commonIndependenceNotice,
      leading: const Icon(SaartheeIcons.check),
      onTap: () {},
    ),
    check: (t, l10n) async {
      expect(find.text(l10n.commonNotifications), findsOneWidget);
      expect(t.getSize(find.byType(ListRow)).height, greaterThanOrEqualTo(56));
      expectSemanticsContaining(l10n.commonNotifications);
    },
  );

  componentMatrix(
    'IssueCard overdue + Me too count + photo',
    (l10n) => IssueCard(
      title: l10n.reportFlowDescriptionHint,
      categorySlug: 'roads',
      wardAndAge: 'Navrangpura · 2',
      status: IssueStatus.inProgress,
      meTooCount: 12,
      overdue: true,
      photo: MemoryImage(tinyPng),
      photoLabel: l10n.reportPhotoPreviewLabel,
      onTap: () {},
    ),
    check: (t, l10n) async {
      expect(find.text(l10n.reportFlowDescriptionHint), findsOneWidget);
      expect(find.text(l10n.statusInProgress), findsOneWidget);
      expect(find.text(l10n.componentMeTooCount(12)), findsOneWidget);
      expect(find.byType(OverdueTag), findsOneWidget);
      expectSemanticsContaining(l10n.statusInProgress);
    },
  );

  componentMatrix(
    'StatusTimeline hollow future steps + after photo slot',
    (l10n) => StatusTimeline(
      steps: [
        const TimelineStep(status: IssueStatus.reported, date: '1 Oct'),
        const TimelineStep(status: IssueStatus.acknowledged),
        TimelineStep(
          status: IssueStatus.markedFixed,
          extra: SizedBox(
            width: 120,
            child: PhotoThumb(
              image: MemoryImage(tinyPng),
              semanticLabel: l10n.reportPhotoPreviewLabel,
            ),
          ),
        ),
        const TimelineStep(status: IssueStatus.verified, isFuture: true),
      ],
    ),
    check: (t, l10n) async {
      for (final w in [
        l10n.statusReported,
        l10n.statusAcknowledged,
        l10n.statusFixed,
        l10n.statusVerified,
      ]) {
        expect(find.text(w), findsOneWidget);
      }
      final future = t.widget<Container>(
        find.byKey(const ValueKey('timeline.dot.3')),
      );
      final deco = future.decoration! as BoxDecoration;
      expect(deco.border, isNotNull, reason: 'future step is hollow');
      expect(deco.color, NeemFixed.transparent);
      expectSemantics(l10n.reportPhotoPreviewLabel);
    },
  );

  componentMatrix(
    'AlertCard × 4 severities with source line and validity',
    (l10n) => Column(
      children: [
        for (final s in AlertSeverity.values)
          AlertCard(
            severity: s,
            title: alertSeverityLabel(l10n, s),
            area: 'Paldi',
            validity: l10n.commonLoading,
            source: 'AMC',
          ),
      ],
    ),
    check: (t, l10n) async {
      expect(find.text(l10n.componentAlertSource('AMC')), findsNWidgets(4));
      expect(find.text(l10n.commonLoading), findsNWidgets(4));
      for (final s in AlertSeverity.values) {
        final word = alertSeverityLabel(l10n, s);
        expect(find.textContaining(word), findsWidgets);
        expect(find.byIcon(AlertSeverityStyle.of(s).icon), findsWidgets);
        expectSemanticsContaining(word);
      }
    },
  );

  componentMatrix(
    'RepresentativeRow: name, role, ward, Message, no phone',
    (l10n) => RepresentativeRow(
      name: 'A. Patel',
      role: l10n.commonNotifications,
      ward: 'Navrangpura',
      onMessage: () {},
    ),
    check: (t, l10n) async {
      expect(find.text('A. Patel'), findsOneWidget);
      expect(find.text(l10n.componentMessage), findsOneWidget);
      expectSemanticsContaining(l10n.componentMessage);
      expect(find.textContaining(RegExp(r'\d{10}')), findsNothing);
    },
  );

  componentMatrix(
    'CategoryBadge × 14 slugs, tinted rounded square, labelled',
    (l10n) => Wrap(
      children: [
        for (final c in CategoryStyle.all) CategoryBadge(slug: c.slug),
      ],
    ),
    check: (t, l10n) async {
      expect(find.byType(CategoryBadge), findsNWidgets(14));
      for (final c in CategoryStyle.all) {
        expectSemantics(categoryLabel(l10n, c.slug));
      }
      expect(t.getSize(find.byType(CategoryBadge).first), const Size(40, 40));
    },
  );
}
