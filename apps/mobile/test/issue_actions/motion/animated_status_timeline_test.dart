// W-06-07 (AC-13, AC-15): only new timeline steps grow from their dot; W-06-03 (AC-10): event → row mapping.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/l10n/app_localizations.dart';
import 'package:saarthee/core/theme/motion.dart';
import 'package:saarthee/core/theme/tokens.dart';
import 'package:saarthee/features/issue_actions/application/timeline_mapping.dart';
import 'package:saarthee/features/issue_actions/presentation/motion/animated_status_timeline.dart';

import '../../helpers/motion.dart';
import '../fakes.dart';

TimelineRow _row(String id, IssueStatus s) =>
    TimelineRow(id: id, status: s, title: s.name, actor: 'A resident of Paldi');

final _initial = [
  for (final (i, s) in [
    IssueStatus.reported,
    IssueStatus.sent,
    IssueStatus.acknowledged,
    IssueStatus.inProgress,
    IssueStatus.reopened,
  ].indexed)
    _row('e$i', s),
];

double _scale(WidgetTester t, String id) => t
    .widget<ScaleTransition>(find.byKey(ValueKey('timeline.dotScale.$id')))
    .scale
    .value;

double _height(WidgetTester t, String id) => t
    .widget<Align>(
      find
          .descendant(
            of: find.byKey(ValueKey('timeline.clip.$id')),
            matching: find.byType(Align),
          )
          .first,
    )
    .heightFactor!;

Future<ValueNotifier<List<TimelineRow>>> _pump(
  WidgetTester t, {
  bool? reduced,
  bool disable = false,
}) async {
  final rows = ValueNotifier(_initial);
  addTearDown(rows.dispose);
  await pumpMotion(
    t,
    SingleChildScrollView(
      child: ValueListenableBuilder<List<TimelineRow>>(
        valueListenable: rows,
        builder: (_, r, _) => AnimatedStatusTimeline(rows: r),
      ),
    ),
    reduced: reduced,
    disableAnimations: disable,
  );
  return rows;
}

void main() {
  testWidgets('initial list of 5 renders without animation', (t) async {
    await _pump(t);
    for (final r in _initial) {
      expect(_scale(t, r.id), 1);
      expect(_height(t, r.id), 1);
    }
  });

  testWidgets(
    'a new event: only that step animates (dot springIn, clipped height medium)',
    (t) async {
      final rows = await _pump(t);
      final oldStep = t.element(find.byKey(const ValueKey('timeline.step.e0')));
      rows.value = [..._initial, _row('new', IssueStatus.markedFixed)];
      await t.pump();
      expect(_scale(t, 'new'), lessThan(1));
      expect(_height(t, 'new'), lessThan(0.05));
      for (final r in _initial) {
        expect(_scale(t, r.id), 1);
        expect(_height(t, r.id), 1);
      }
      await t.pump(SaartheeMotion.medium.duration ~/ 2);
      expect(_height(t, 'new'), inExclusiveRange(0, 1));
      await t.pump(SaartheeMotion.springIn.duration);
      await t.pump(SaartheeMotion.medium.duration);
      expect(_scale(t, 'new'), 1);
      expect(_height(t, 'new'), 1);
      // Existing steps kept their element (keys unchanged, no rebuild from scratch).
      expect(
        t.element(find.byKey(const ValueKey('timeline.step.e0'))),
        same(oldStep),
      );
    },
  );

  for (final variant in ['system', 'in-app']) {
    testWidgets(
      'reduced motion ($variant): new step present on the next frame',
      (t) async {
        final rows = variant == 'system'
            ? await _pump(t, disable: true)
            : await _pump(t, reduced: true);
        rows.value = [..._initial, _row('new', IssueStatus.markedFixed)];
        await t.pump();
        expect(_scale(t, 'new'), 1);
        expect(_height(t, 'new'), 1);
      },
    );
  }

  test('W-06-03: events map to privacy-safe actors and the after photo sits on Fixed', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final rows = timelineRows(l10n, [
      ev('a', 'status_change', to: 'reported'),
      ev('b', 'ccrs_linked', note: 'via:web'),
      ev(
        'c',
        'status_change',
        to: 'acknowledged',
        actor: 'representative',
        nameEn: 'Ila Shah',
        repRole: 'corporator',
      ),
      ev(
        'd',
        'status_change',
        to: 'marked_fixed',
        actor: 'moderator',
        photos: ['/api/v1/media/photos/p1?w=1024'],
      ),
      ev('e', 'verification', answer: 'fixed'),
      ev('f', 'status_change', to: 'verified', actor: 'system'),
      ev('g', 'escalated', level: 'corporators'),
      ev('h', 'system', actor: 'system', note: 'overdue'),
      ev('i', 'comment'),
    ], localeName: 'en');
    expect(rows.map((r) => r.title), [
      'Reported',
      'AMC complaint linked',
      'Acknowledged',
      'Fixed',
      "Said it's fixed",
      'Verified',
      'Escalated',
      'Past its target date',
    ]);
    expect(rows.map((r) => r.actor), [
      'A resident of Paldi',
      'A resident of Paldi',
      'Ward corporator Ila Shah',
      'Saarthee moderator',
      'A resident of Paldi',
      'Saarthee',
      'A resident of Paldi',
      'Saarthee',
    ]);
    expect(rows[3].photoUrl, '/api/v1/media/photos/p1?w=1024');
    expect(rows.where((r) => r.photoUrl != null), hasLength(1));
    expect(rows[4].status, IssueStatus.markedFixed);
    final gu = timelineRows(lookupAppLocalizations(const Locale('gu')), [
      ev('a', 'status_change', to: 'reported'),
    ], localeName: 'gu');
    expect(gu.single.actor, 'પાલડીના એક રહેવાસી');
  });
}
