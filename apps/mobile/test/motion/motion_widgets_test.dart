// T-03-26 reusable motion widgets pumped through the token durations.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/motion/motion_widgets.dart';
import 'package:saarthee/core/widgets/rolling_count.dart';

import '../helpers/motion.dart';

const _ms = Duration(milliseconds: 1);

double _checkProgress(WidgetTester t) {
  final paint = t.widget<CustomPaint>(
    find.descendant(
      of: find.byType(MotionCheck),
      matching: find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is CheckPainter,
      ),
    ),
  );
  return (paint.painter! as CheckPainter).progress;
}

double _opacityOf(WidgetTester t, String text) => t
    .widget<Opacity>(
      find.ancestor(of: find.text(text), matching: find.byType(Opacity)).first,
    )
    .opacity;

void main() {
  testWidgets('MotionCheck: waits 150 ms, done by 600 ms', (t) async {
    await pumpMotion(
      t,
      const MotionCheck(color: Colors.black, semanticLabel: 'Done'),
    );
    await t.pump(_ms * 149);
    expect(_checkProgress(t), 0);
    await t.pump(_ms * 51);
    await t.pump(_ms * 16); // first vsync after the 150 ms delay
    expect(_checkProgress(t), greaterThan(0));
    await t.pump(_ms * 450);
    expect(_checkProgress(t), 1);
    expect(find.bySemanticsLabel('Done'), findsOneWidget);
  });

  testWidgets('CountUp 0 → 37: integers only, 37 at 600 ms', (t) async {
    final value = ValueNotifier(37);
    await pumpMotion(
      t,
      ValueListenableBuilder<int>(
        valueListenable: value,
        builder: (_, v, _) => CountUp(value: v),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await t.pump(_ms * 100);
      final shown = t.widget<Text>(find.byType(Text)).data!;
      expect(int.tryParse(shown), isNotNull, reason: shown);
    }
    expect(find.text('37'), findsOneWidget);
    value.value = 37; // same value: no replay
    await t.pump(_ms * 50);
    expect(find.text('37'), findsOneWidget);
  });

  testWidgets('StaggeredColumn: 60 ms apart, 7+ with item 6', (t) async {
    await pumpMotion(
      t,
      StaggeredColumn(
        children: [for (var i = 0; i < 10; i++) Text('item$i')],
      ),
    );
    await t.pump(_ms * 30);
    expect(_opacityOf(t, 'item0'), greaterThan(0));
    expect(_opacityOf(t, 'item1'), 0);
    expect(staggerDelay(SaartheeMotion.full, 1), _ms * 60);
    expect(staggerDelay(SaartheeMotion.full, 5), _ms * 300);
    expect(staggerDelay(SaartheeMotion.full, 9), _ms * 300);
    await t.pumpAndSettle();
    expect(_opacityOf(t, 'item9'), 1);
  });

  testWidgets('SeenOnce: animates the first mount only', (t) async {
    final calls = <bool>[];
    Widget probe() => SeenOnce(
      seenKey: 'home.feed',
      builder: (_, animate) {
        calls.add(animate);
        return const SizedBox();
      },
    );
    final show = ValueNotifier(true);
    final container = await pumpMotion(
      t,
      ValueListenableBuilder<bool>(
        valueListenable: show,
        builder: (_, s, _) => s ? probe() : const SizedBox(),
      ),
    );
    expect(calls, [true]);
    show.value = false; // leave the tab
    await t.pump();
    show.value = true; // come back: end state, no replay
    await t.pump();
    expect(calls.last, isFalse);
    final seen = container.read(seenOnceProvider);
    expect(seen.markFirstView('ward.page'), isTrue); // a new key animates
  });

  testWidgets('PopIn uses tileStagger (35 ms)', (t) async {
    expect(SaartheeMotion.full.tileStagger, _ms * 35);
    await pumpMotion(t, const PopIn(index: 1, child: Text('tile')));
    await t.pumpAndSettle();
    expect(find.text('tile'), findsOneWidget);
  });

  testWidgets('RollingCount: new value by 180 ms, semantics final', (t) async {
    final value = ValueNotifier(4);
    await pumpMotion(
      t,
      ValueListenableBuilder<int>(
        valueListenable: value,
        builder: (_, v, _) => RollingCount(value: v),
      ),
    );
    value.value = 5;
    await t.pump();
    expect(find.bySemanticsLabel('5'), findsOneWidget);
    await t.pump(_ms * 16); // ticker starts on the next frame
    await t.pump(_ms * 180);
    await t.pump();
    expect(find.text('5'), findsOneWidget);
    expect(find.text('4'), findsNothing);
  });
}
