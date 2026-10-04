// T-03-12 five-tab shell, T-03-11 gallery route, placeholder register.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:saarthee/core/theme/tokens.dart';

import 'package:saarthee/features/dev/gallery_screen.dart';
import 'package:saarthee/router/app_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../helpers/app.dart';

const _replays = ['Launch mark', 'Shared axis', 'Fade through'];

/// Scrolls the visible tab's list until [f] is built and on screen.
Future<void> reveal(WidgetTester t, Finder f) async {
  if (f.evaluate().isNotEmpty) return;
  await t.scrollUntilVisible(
    f,
    120,
    scrollable: find.byType(Scrollable).hitTestable().first,
  );
  await t.pumpAndSettle();
}

Future<void> tab(WidgetTester t, int i) async {
  await t.tap(find.byKey(Key('nav.$i')));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('five labelled destinations, Report glyph in sunrise', (t) async {
    await pumpApp(t, prefs: onboardedPrefs());
    final nav = find.byType(NavigationBar);
    for (final label in ['Home', 'Map', 'Report', 'Alerts', 'My Ward']) {
      expect(
        find.descendant(of: nav, matching: find.text(label)),
        findsOneWidget,
        reason: label,
      );
    }
    final reportIcon = t.widget<Icon>(
      find.descendant(
        of: find.byKey(const Key('nav.2')),
        matching: find.byType(Icon),
      ),
    );
    expect(reportIcon.color, SaartheeColors.of(t.element(nav)).sunrise);
  });

  testWidgets('placeholders P-01..P-07 are in place; P-09 → account row', (
    t,
  ) async {
    await pumpApp(t, prefs: onboardedPrefs());
    // TASK-12 replaced P-03 (Home drives/services) and P-08 (My Ward
    // services); see test/services/home_ward_sections_test.dart.
    const byTab = {
      0: ['P-02', 'P-01'],
      1: ['P-04'],
      2: ['P-05'],
      3: ['P-06'],
      4: ['P-07'],
    };
    for (final e in byTab.entries) {
      await tab(t, e.key);
      for (final id in e.value) {
        final f = find.byKey(ValueKey('placeholder.$id'));
        await reveal(t, f);
        expect(f, findsOneWidget, reason: id);
      }
    }
    // TASK-04 replaced P-09 with the account row.
    final me = find.byKey(const Key('myWard.me'));
    await reveal(t, me);
    expect(me, findsOneWidget);
    expect(find.byKey(const ValueKey('placeholder.P-09')), findsNothing);
  });

  testWidgets('tabs keep their pushed page and scroll; re-tap pops', (t) async {
    await pumpApp(t, prefs: onboardedPrefs());
    ScrollPosition homePos() => t
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byKey(const PageStorageKey('home.scroll')),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position;
    homePos().jumpTo(120);
    await t.pump();
    await tab(t, 4);
    await reveal(t, find.byKey(const Key('myWard.settings')));
    await t.tap(find.byKey(const Key('myWard.settings')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('settings.animations')), findsOneWidget);
    await tab(t, 3);
    await tab(t, 4);
    expect(find.byKey(const Key('settings.animations')), findsOneWidget);
    await tab(t, 4); // re-tap the active tab → root
    expect(find.byKey(const Key('settings.animations')), findsNothing);
    await tab(t, 0);
    expect(homePos().pixels, 120);
  });

  testWidgets('T-03-11 /dev/gallery opens in debug builds', (t) async {
    await pumpApp(t, prefs: onboardedPrefs());
    GoRouter.of(t.element(find.byType(NavigationBar))).push('/dev/gallery');
    // The gallery shows shimmering skeletons: pump, don't settle.
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byKey(const Key('gallery.list')), findsOneWidget);
    expect(find.byKey(const Key('gallery.reduced')), findsOneWidget);
    expect(GalleryScreen.motionEntries, containsAll(_replays));
    expect(GalleryScreen.motionEntries.length, 15);
  });

  testWidgets('T-03-11 gallery route absent when enableGallery is false', (
    t,
  ) async {
    final c = await pumpApp(t, prefs: onboardedPrefs());
    final noGallery = Provider<GoRouter>(
      (ref) => buildAppRouter(ref, enableGallery: false),
    );
    final router = c.read(noGallery);
    addTearDown(router.dispose);
    final paths = router.configuration.routes.whereType<GoRoute>().map(
      (r) => r.path,
    );
    expect(paths, isNot(contains('/dev/gallery')));
    final withGallery = c
        .read(appRouterProvider)
        .configuration
        .routes
        .whereType<GoRoute>()
        .map((r) => r.path);
    expect(withGallery, contains('/dev/gallery'));
  });
}
