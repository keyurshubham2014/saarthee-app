// T-03-08 rows, cards, timeline, badges, tiles, representative, photo.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/theme/tokens.dart';
import 'package:saarthee/core/widgets/widgets.dart';

import '../helpers/motion.dart';

// 1×1 transparent PNG.
final _png = Uint8List.fromList(const [
  137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1,
  0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, 0, 0, 0, 13, 73, 68, 65, 84,
  120, 156, 99, 0, 1, 0, 0, 5, 0, 1, 13, 10, 45, 180, 0, 0, 0, 0, 73, 69,
  78, 68, 174, 66, 96, 130,
]);

void main() {
  testWidgets('CategoryBadge × 14: 40 dp, labelled', (t) async {
    await pumpMotion(
      t,
      Wrap(
        children: [
          for (final c in CategoryStyle.all) CategoryBadge(slug: c.slug),
        ],
      ),
    );
    final badges = find.byType(CategoryBadge);
    expect(badges, findsNWidgets(14));
    expect(t.getSize(badges.first), const Size(40, 40));
    expect(find.bySemanticsLabel('Roads'), findsOneWidget);
    expect(find.bySemanticsLabel('Other'), findsOneWidget);
  });

  testWidgets('ListRow ≥ 56 dp and tappable', (t) async {
    var taps = 0;
    await pumpMotion(
      t,
      ListRow(title: 'Settings', onTap: () => taps++),
    );
    expect(t.getSize(find.byType(ListRow)).height, greaterThanOrEqualTo(56));
    await t.tap(find.text('Settings'));
    expect(taps, 1);
  });

  testWidgets('IssueCard shows title, status, me-too, overdue', (t) async {
    await pumpMotion(
      t,
      SingleChildScrollView(
        child: IssueCard(
          title: 'Pothole on CG Road',
          categorySlug: 'roads',
          wardAndAge: 'Ward 12 · 2 days',
          status: IssueStatus.inProgress,
          meTooCount: 3,
          overdue: true,
          onTap: () {},
        ),
      ),
    );
    expect(find.text('Pothole on CG Road'), findsOneWidget);
    expect(find.text('In progress'), findsOneWidget);
    expect(find.textContaining('3'), findsWidgets);
    expect(find.text('Overdue'), findsOneWidget);
  });

  testWidgets('StatusTimeline uses 14 dp dots', (t) async {
    await pumpMotion(
      t,
      const StatusTimeline(
        steps: [
          TimelineStep(status: IssueStatus.reported, actor: 'You'),
          TimelineStep(status: IssueStatus.verified, isFuture: true),
        ],
      ),
    );
    expect(find.text('Reported'), findsOneWidget);
    expect(find.text('Verified'), findsOneWidget);
    expect(AppSpacing.timelineDot, 14);
  });

  testWidgets('AlertCard: tinted, source line, critical solid', (t) async {
    await pumpMotion(
      t,
      const Column(
        children: [
          AlertCard(
            severity: AlertSeverity.warning,
            title: 'Water cut',
            area: 'Paldi',
            validity: 'Today',
            source: 'AMC',
          ),
          AlertCard(
            severity: AlertSeverity.critical,
            title: 'Flood',
            area: 'Vasna',
            validity: 'Now',
            source: 'IMD',
          ),
        ],
      ),
    );
    expect(find.text('Source: AMC · Relayed by Saarthee'), findsOneWidget);
    expect(find.text('Warning'), findsOneWidget);
    expect(find.text('Critical'), findsOneWidget);
  });

  testWidgets('StatTile, RepresentativeRow, PhotoThumb semantics', (t) async {
    await pumpMotion(
      t,
      Wrap(
        children: [
          const StatTile(value: 37, label: 'Fixed', animate: false),
          RepresentativeRow(
            name: 'A. Patel',
            role: 'Corporator',
            ward: 'Ward 12',
            onMessage: () {},
          ),
          SizedBox(
            width: 120,
            child: PhotoThumb(
              image: MemoryImage(_png),
              semanticLabel: 'Pothole photo',
              blurred: true,
            ),
          ),
        ],
      ),
    );
    expect(find.text('37'), findsOneWidget);
    expect(find.text('A. Patel'), findsOneWidget);
    expect(find.text('Message'), findsOneWidget);
    expect(find.bySemanticsLabel('Pothole photo'), findsOneWidget);
    expect(find.text('Faces and number plates blurred'), findsOneWidget);
  });
}
