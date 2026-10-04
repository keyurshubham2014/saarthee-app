// a11y audit (TASK-14, 2.0× Gujarati): the organiser line never touches the
// going count, and nothing overflows.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/features/initiatives/presentation/widgets/initiative_card.dart';

import '../helpers/motion.dart';
import '../services/fakes.dart';

void main() {
  for (final locale in const [Locale('en'), Locale('gu')]) {
    testWidgets(
      'organiser and count keep a gap at 2.0× (${locale.languageCode})',
      (t) async {
        t.view.physicalSize = const Size(1080, 2400);
        t.view.devicePixelRatio = 2.625;
        addTearDown(t.view.reset);
        await pumpMotion(
          t,
          SingleChildScrollView(
            child: InitiativeCard(
              initiative: drive(),
              lang: locale.languageCode,
              onTap: () {},
            ),
          ),
          reduced: true,
          locale: locale,
          textScale: 2,
        );
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        final organiser = find.textContaining('Paldi RWA');
        final count = find.textContaining('3 ');
        expect(organiser, findsOneWidget);
        final gap = t.getTopLeft(count.last).dx - t.getTopRight(organiser).dx;
        expect(gap, greaterThanOrEqualTo(12));
      },
    );
  }
}
