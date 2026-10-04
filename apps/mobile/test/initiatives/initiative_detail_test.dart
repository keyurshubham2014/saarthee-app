// T-12-17 (AC-6, AC-10): initiative detail — RSVP signs in first then POSTs;
// full, cancelled and past states; list "My ward" / "All city".
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_wards.dart';
import '../services/fakes.dart';
import '../services/harness.dart';

void main() {
  testWidgets(
    'T-12-17 "I\'m going" calls ensureSignedIn, then POST; declined sign-in sends nothing',
    (t) async {
      final repo = FakeInitiativesRepository([drive()]);
      final signIn = SignInRecorder(repo.calls, allow: false);
      await pumpServices(
        t,
        location: '/initiatives/i1',
        initiatives: repo,
        signIn: signIn,
      );
      expect(find.text('Canal clean-up'), findsWidgets);
      expect(find.text('By Paldi RWA'), findsOneWidget);
      expect(find.byKey(const Key('initiative.maps')), findsOneWidget);
      expect(find.byKey(const Key('initiative.source')), findsOneWidget);

      await t.scrollUntilVisible(find.byKey(const Key('rsvp.button')), 200);
      await t.tap(find.byKey(const Key('rsvp.button')));
      await t.pump();
      expect(repo.calls, ['signIn']);

      signIn.allow = true;
      await t.tap(find.byKey(const Key('rsvp.button')));
      await t.pump();
      await t.pump();
      expect(repo.calls, ['signIn', 'signIn', 'rsvp:i1']);
      await t.pumpAndSettle();
      expect(find.text("You're going"), findsOneWidget);
      expect(find.text("We'll remind you a day before."), findsOneWidget);
    },
  );

  testWidgets('T-12-17 full drive → disabled "This drive is full"', (t) async {
    final repo = FakeInitiativesRepository([drive(going: 20, capacity: 20)]);
    await pumpServices(
      t,
      location: '/initiatives/i1',
      initiatives: repo,
      signIn: SignInRecorder(repo.calls),
    );
    await t.scrollUntilVisible(find.byKey(const Key('rsvp.button')), 200);
    expect(find.text('This drive is full'), findsOneWidget);
    await t.tap(find.byKey(const Key('rsvp.button')));
    await t.pump();
    expect(repo.calls, isEmpty);
  });

  testWidgets('T-12-17 cancelled → banner and no RSVP; past → no RSVP button', (
    t,
  ) async {
    await pumpServices(
      t,
      location: '/initiatives/i1',
      initiatives: FakeInitiativesRepository([drive(status: 'cancelled')]),
    );
    expect(find.byKey(const Key('initiative.cancelled')), findsOneWidget);
    expect(find.text('Cancelled by the organiser'), findsOneWidget);
    expect(find.byKey(const Key('rsvp.button')), findsNothing);

    await pumpServices(
      t,
      location: '/initiatives/i2',
      initiatives: FakeInitiativesRepository([
        drive(id: 'i2', startsIn: const Duration(hours: -1)),
      ]),
    );
    expect(find.byKey(const Key('rsvp.button')), findsNothing);
    expect(find.byKey(const Key('rsvp.count')), findsOneWidget);
  });

  testWidgets(
    'T-12-17 list: My ward shows ward + city-wide; empty ward offers "See all city"',
    (t) async {
      final repo = FakeInitiativesRepository([
        drive(id: 'a', wardId: 'w12'),
        drive(id: 'b', wardId: null),
        drive(id: 'c', wardId: 'w13'),
      ]);
      await pumpServices(
        t,
        location: '/initiatives',
        initiatives: repo,
        prefs: homeWardPrefs(paldi),
      );
      expect(find.byKey(const Key('initiative.card.a')), findsOneWidget);
      expect(find.byKey(const Key('initiative.card.b')), findsOneWidget);
      expect(find.byKey(const Key('initiative.card.c')), findsNothing);
      await t.tap(find.text('All city'));
      await t.pump();
      await t.pump();
      expect(find.byKey(const Key('initiative.card.c')), findsOneWidget);

      await pumpServices(
        t,
        location: '/initiatives',
        initiatives: FakeInitiativesRepository([drive(id: 'c', wardId: 'w13')]),
        prefs: homeWardPrefs(paldi),
      );
      expect(find.text('No upcoming drives in your ward.'), findsOneWidget);
      await t.tap(find.text('See all city'));
      await t.pump();
      await t.pump();
      expect(find.byKey(const Key('initiative.card.c')), findsOneWidget);
    },
  );
}
