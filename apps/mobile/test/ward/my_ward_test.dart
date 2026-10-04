// W-09-01 representative row, W-09-02 My Ward states, W-09-05 election
// banner (TASK-09 AC-1, AC-11).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/api/app_error.dart';
import 'package:saarthee/features/ward/data/ward_models.dart';
import 'package:saarthee/features/ward/presentation/election_banner.dart';
import 'package:saarthee/features/ward/presentation/rep_row.dart';

import '../helpers/motion.dart';
import 'ward_fakes.dart';

void main() {
  group('W-09-01 representative row', () {
    testWidgets('initials, both scripts, role · party, Message semantics', (
      t,
    ) async {
      var messaged = 0;
      final handle = t.ensureSemantics();
      await pumpMotion(
        t,
        WardRepRow(
          rep: RepSummary.fromJson(repJson('c0', 'Sample Corporator A')),
          lang: 'en',
          onOpen: () {},
          onMessage: () => messaged++,
        ),
      );
      expect(find.text('SC'), findsOneWidget);
      expect(find.text('Sample Corporator A'), findsOneWidget);
      expect(find.text('નમૂના Sample Corporator A'), findsOneWidget);
      expect(find.text('Corporator · Sample Party'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'Message Sample Corporator A, Corporator, ward 30',
        ),
        findsOneWidget,
      );
      final size = t.getSize(find.byKey(const Key('rep.message.c0')));
      expect(size.height, greaterThanOrEqualTo(48));
      await t.tap(find.byKey(const Key('rep.message.c0')));
      expect(messaged, 1);
      handle.dispose();
    });

    testWidgets('no email → same layout, Message disabled', (t) async {
      await pumpMotion(
        t,
        WardRepRow(
          rep: RepSummary.fromJson(
            repJson('c1', 'Sample B', canMessage: false),
          ),
          lang: 'gu',
          onOpen: () {},
          onMessage: null,
        ),
      );
      final btn = t.widget<ButtonStyleButton>(
        find.byKey(const Key('rep.message.c1')),
      );
      expect(btn.onPressed, isNull);
      // Gujarati UI: Gujarati name first, English below.
      expect(find.text('નમૂના Sample B'), findsOneWidget);
    });
  });

  group('W-09-02 My Ward states', () {
    testWidgets(
      '4 corporators, MLAs with the 2-AC note, MP, office, scorecard',
      (t) async {
        final launched = <Uri>[];
        await pumpWardRoutes(t, api: FakeWardApi(), launched: launched);
        await t.pumpAndSettle();
        for (final id in ['c0', 'c1', 'c2', 'c3', 'm0', 'm1', 'p0']) {
          expect(find.byKey(Key('ward.rep.$id')), findsOneWidget, reason: id);
        }
        expect(
          find.text('Your ward is in 2 assembly constituencies.'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('ward.pendingSeat.3')), findsNothing);
        await t.ensureVisible(find.byKey(const Key('ward.office.call')));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('ward.office.call')));
        expect(launched.single.toString(), 'tel:+917900003001');
        expect(find.byKey(const Key('ward.scorecardRow')), findsOneWidget);
      },
    );

    testWidgets('fewer than 4 corporators → "Seat details being checked"', (
      t,
    ) async {
      await pumpWardRoutes(t, api: FakeWardApi(reps: wardReps(corporators: 2)));
      await t.pumpAndSettle();
      expect(find.text('Seat details being checked'), findsNWidgets(2));
    });

    testWidgets('no representatives → message, ward office still shown', (
      t,
    ) async {
      await pumpWardRoutes(
        t,
        api: FakeWardApi(
          reps: wardReps(corporators: 0, mlas: 0, mps: 0, acCount: 0),
        ),
      );
      await t.pumpAndSettle();
      expect(
        find.text("We're still adding representatives for this ward."),
        findsOneWidget,
      );
      expect(find.byKey(const Key('ward.office')), findsOneWidget);
    });

    testWidgets('error → "We couldn\'t load your ward." + Try again', (
      t,
    ) async {
      final api = FakeWardApi()
        ..repsError = const AppError(code: 'INTERNAL_ERROR');
      await pumpWardRoutes(t, api: api);
      await t.pumpAndSettle();
      expect(find.text("We couldn't load your ward."), findsOneWidget);
      api.repsError = null;
      await t.tap(find.text('Try again'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('ward.rep.c0')), findsOneWidget);
    });

    testWidgets(
      'offline after a load → last cached ward with the offline note',
      (t) async {
        final api = FakeWardApi();
        final r = await pumpWardRoutes(t, api: api);
        await t.pumpAndSettle();
        api.repsError = const AppError.offline();
        r.router.go('/');
        await t.pumpAndSettle();
        r.router.go('/ward/$wardId');
        await t.pumpAndSettle();
        expect(
          find.text("You're offline. Showing what we loaded earlier."),
          findsOneWidget,
        );
        expect(find.byKey(const Key('ward.rep.c0')), findsOneWidget);
      },
    );

    testWidgets('offline with nothing cached → offline state', (t) async {
      final api = FakeWardApi()..repsError = const AppError.offline();
      await pumpWardRoutes(t, api: api);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('ward.rep.c0')), findsNothing);
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('W-09-05 election banner', () {
    testWidgets('text with the end date, live region; hidden when off', (
      t,
    ) async {
      final handle = t.ensureSemantics();
      await pumpMotion(
        t,
        ElectionBanner(
          status: ElectionStatus(
            active: true,
            until: DateTime.utc(2026, 11, 1),
          ),
        ),
      );
      expect(
        find.text(
          'Election period until Nov 1, 2026. Some representative information is paused.',
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('ward.electionBanner')),
          matching: find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.liveRegion == true,
          ),
        ),
        findsOneWidget,
      );
      handle.dispose();
      await pumpMotion(t, const ElectionBanner(status: ElectionStatus.off));
      expect(find.byKey(const Key('ward.electionBanner')), findsNothing);
    });

    testWidgets('My Ward shows the banner when election mode is active', (
      t,
    ) async {
      await pumpWardRoutes(t, api: FakeWardApi(reps: wardReps(election: true)));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('ward.electionBanner')), findsOneWidget);
    });
  });
}
