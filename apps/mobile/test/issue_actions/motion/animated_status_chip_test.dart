// W-06-06 (AC-13, AC-15): AnimatedStatusChip cross-fade and TalkBack announcement.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/l10n/app_localizations.dart';
import 'package:saarthee/core/theme/motion.dart';
import 'package:saarthee/core/theme/tokens.dart';
import 'package:saarthee/features/issue_actions/presentation/motion/animated_status_chip.dart';

import '../../helpers/motion.dart';
import '../fakes.dart';

const _from = ValueKey('statusChip.inProgress');
const _to = ValueKey('statusChip.markedFixed');

double _opacityOf(WidgetTester t, Key key) => t
    .widget<Opacity>(
      find.ancestor(of: find.byKey(key), matching: find.byType(Opacity)).first,
    )
    .opacity;

Future<ValueNotifier<IssueStatus>> _pump(
  WidgetTester t, {
  bool? reduced,
  bool disableAnimations = false,
  Locale locale = const Locale('en'),
}) async {
  final status = ValueNotifier(IssueStatus.inProgress);
  addTearDown(status.dispose);
  await pumpMotion(
    t,
    Center(
      child: ValueListenableBuilder<IssueStatus>(
        valueListenable: status,
        builder: (_, s, _) => AnimatedStatusChip(status: s),
      ),
    ),
    reduced: reduced,
    disableAnimations: disableAnimations,
    locale: locale,
  );
  return status;
}

void main() {
  testWidgets('first build: no animation and no announcement', (t) async {
    final announced = captureAnnouncements(t);
    await _pump(t);
    expect(find.byKey(_from), findsOneWidget);
    expect(find.byType(Opacity), findsNothing);
    expect(announced, isEmpty);
  });

  testWidgets(
    'in_progress → marked_fixed cross-fades over short and announces once',
    (t) async {
      final announced = captureAnnouncements(t);
      final status = await _pump(t);
      status.value = IssueStatus.markedFixed;
      await t.pump();
      await t.pump(SaartheeMotion.short.duration ~/ 2);
      expect(find.byKey(_from), findsOneWidget);
      expect(find.byKey(_to), findsOneWidget);
      expect(_opacityOf(t, _from), inExclusiveRange(0, 1));
      expect(_opacityOf(t, _to), inExclusiveRange(0, 1));
      await t.pump(SaartheeMotion.short.duration);
      expect(find.byKey(_from), findsNothing);
      expect(find.byKey(_to), findsOneWidget);
      expect(
        find.byIcon(IssueStatusStyle.of(IssueStatus.markedFixed).icon),
        findsOneWidget,
      );
      expect(find.text('Fixed'), findsOneWidget);
      expect(announced, ['Status changed to Fixed']);
      // A rebuild with the same status neither animates nor announces again.
      status.value = IssueStatus.markedFixed;
      await t.pump(SaartheeMotion.short.duration);
      expect(announced, hasLength(1));
    },
  );

  testWidgets('Gujarati announcement', (t) async {
    final announced = captureAnnouncements(t);
    final status = await _pump(t, locale: const Locale('gu'));
    status.value = IssueStatus.markedFixed;
    await t.pump();
    await t.pump(SaartheeMotion.short.duration);
    final gu = lookupAppLocalizations(const Locale('gu'));
    expect(announced, [gu.issueActionsStatusAnnounce(gu.statusFixed)]);
    expect(announced.single, startsWith('સ્થિતિ બદલાઈ: '));
  });

  for (final variant in ['system', 'in-app']) {
    testWidgets(
      'reduced motion ($variant): final chip on the next frame, still announced once',
      (t) async {
        final announced = captureAnnouncements(t);
        final status = variant == 'system'
            ? await _pump(t, disableAnimations: true)
            : await _pump(t, reduced: true);
        status.value = IssueStatus.markedFixed;
        await t.pump();
        expect(find.byKey(_from), findsNothing);
        expect(find.byKey(_to), findsOneWidget);
        expect(announced, ['Status changed to Fixed']);
      },
    );
  }
}
