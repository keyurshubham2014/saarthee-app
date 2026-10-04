// Overscroll never stretches (scales) content on Android: no stretch or glow
// indicator wraps scrollables, and an overscroll leaves item sizes unchanged.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/theme/scroll_behavior.dart';

void main() {
  testWidgets(
    'no stretch overscroll on Android',
    variant: const TargetPlatformVariant({TargetPlatform.android}),
    (t) async {
      await t.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          scrollBehavior: const SaartheeScrollBehavior(),
          home: Scaffold(
            body: ListView(
              children: [
                for (var i = 0; i < 30; i++)
                  SizedBox(height: 60, child: Text('row $i', key: Key('r$i'))),
              ],
            ),
          ),
        ),
      );
      expect(find.byType(StretchingOverscrollIndicator), findsNothing);
      expect(find.byType(GlowingOverscrollIndicator), findsNothing);
      final before = t.getSize(find.byKey(const Key('r0')));
      final gesture = await t.startGesture(
        t.getCenter(find.byKey(const Key('r3'))),
      );
      await gesture.moveBy(const Offset(0, 300));
      await t.pump();
      expect(t.getSize(find.byKey(const Key('r0'))), before);
      expect(t.getTopLeft(find.byKey(const Key('r0'))).dy, 0);
      await gesture.up();
    },
  );
}
