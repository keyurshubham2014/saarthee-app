// W-10-01 (nav by role, registry hides unlanded items), W-10-02 (responsive
// shell at 1,280 and 360 dp), AC-1 forbidden page and dashboard counts.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/features/staff/shared/staff_shared.dart';
import 'package:saarthee/features/staff/shell/staff_shell.dart';
import 'package:saarthee/features/staff/ward_dashboard/rep_console_api.dart';
import 'package:saarthee/features/staff/ward_dashboard/ward_dashboard_screen.dart';

import 'rep_console_fakes.dart';
import 'staff_harness.dart';

List<String> _navRoutes(WidgetTester t) => [
  for (final e
      in find
          .byWidgetPredicate(
            (w) =>
                w.key is ValueKey<String> &&
                (w.key! as ValueKey<String>).value.startsWith('staff.nav.'),
          )
          .evaluate())
    (e.widget.key! as ValueKey<String>).value.substring('staff.nav.'.length),
];

void main() {
  testWidgets('W-10-01 admin sees every landed section in order', (t) async {
    await pumpStaff(t, location: '/staff', role: 'admin');
    expect(_navRoutes(t), [
      '/staff',
      '/staff/moderation',
      '/staff/alerts',
      '/staff/ward', // TASK-11
      '/staff/ward/issues',
      '/staff/services',
      '/staff/initiatives',
      '/staff/tips',
      '/staff/categories',
      '/staff/users',
      '/staff/settings',
      '/staff/exports',
    ]);
    // TASK-11 Claims is last (below the fold of the lazily built nav list).
    expect(staffNavFor('admin').last.route, '/staff/claims');
    expect(find.text('Administration'), findsOneWidget);
    expect(find.byKey(const Key('staff.roleChip')), findsOneWidget);
    expect(find.byKey(const Key('staff.brandMark')), findsOneWidget);
    expect(find.text('Admin'), findsWidgets);
    expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets(
    'W-10-01 moderator sees Dashboard, Moderation, Alerts (+ TASK-11 ward, claims)',
    (t) async {
      await pumpStaff(t, location: '/staff', role: 'moderator');
      expect(_navRoutes(t), [
        '/staff',
        '/staff/moderation',
        '/staff/alerts',
        // TASK-11 ward console (any ward) and claims (read only).
        '/staff/ward',
        '/staff/ward/issues',
        '/staff/claims',
      ]);
    },
  );

  testWidgets(
    'W-10-01 moderator opening an admin page gets the forbidden page',
    (t) async {
      await pumpStaff(t, location: '/staff/users', role: 'moderator');
      expect(find.byKey(const Key('staff.forbidden')), findsOneWidget);
      await t.tap(find.text('Go to dashboard'));
      await t.pumpAndSettle();
      expect(find.text('Sensitive reports to review'), findsOneWidget);
    },
  );

  test('W-10-01 the registry only lists landed screens; email admins get TASK-10/08 items', () {
    final routes = staffNavItems.map((i) => i.route).toSet();
    expect(routes.any((r) => r.contains('representatives')), isFalse);
    // TASK-11 landed the representative console.
    expect(staffNavFor('representative').map((i) => i.route), [
      '/staff/ward',
      '/staff/ward/issues',
      '/staff/messages',
    ]);
    expect(
      staffNavFor('admin', emailSession: true).map((i) => i.route),
      isNot(contains('/staff/services')),
    );
    expect(staffItemFor('/staff/alerts/new')?.route, '/staff/alerts');
    expect(staffItemFor('/staff')?.route, '/staff');
  });

  testWidgets(
    'W-10-02 1,280 dp: persistent side navigation, content ≤ 1,200 dp',
    (t) async {
      await pumpStaff(t, location: '/staff', size: const Size(1280, 800));
      expect(find.byType(StaffSideNav), findsOneWidget);
      expect(find.byKey(const Key('staff.menu')), findsNothing);
      final box = t.getSize(
        find.byKey(const Key('staff.dash.sensitive')).first,
      );
      expect(box.width, lessThanOrEqualTo(1200));
    },
  );

  testWidgets('W-10-02 360 dp: app bar menu opens the drawer', (t) async {
    await pumpStaff(t, location: '/staff', size: const Size(360, 780));
    expect(find.byType(StaffSideNav), findsNothing);
    await t.tap(find.byKey(const Key('staff.menu')));
    await t.pumpAndSettle();
    expect(find.byType(StaffSideNav), findsOneWidget);
    await t.tap(find.byKey(const Key('staff.nav./staff/moderation')));
    await t.pumpAndSettle();
    expect(find.text('Moderation'), findsWidgets);
  });

  testWidgets(
    'dashboard count cards show final numbers on the first frame and link to lists',
    (t) async {
      final r = await pumpStaff(t, location: '/staff');
      expect(find.text('3'), findsOneWidget);
      expect(find.byKey(const Key('staff.dash.flagged.count')), findsOneWidget);
      await t.tap(find.byKey(const Key('staff.dash.flagged')));
      await t.pumpAndSettle();
      expect(
        r.router.routerDelegate.currentConfiguration.uri.toString(),
        '/staff/moderation?tab=flagged',
      );
    },
  );

  testWidgets('TASK-11 a representative at /staff gets the ward dashboard', (
    t,
  ) async {
    // Regression (emulator 2026-10-04): `/staff` belongs to the Dashboard item,
    // which representatives don't hold, so the role check refused the page.
    await pumpStaff(
      t,
      location: '/staff',
      role: 'representative',
      overrides: [repConsoleApiProvider.overrideWithValue(FakeRepConsoleApi())],
    );
    expect(find.byType(WardDashboardScreen), findsOneWidget);
    expect(find.byKey(const Key('staff.forbidden')), findsNothing);
  });

  // V2-TASK-14 polish: "Saarthee s…" truncated next to the role chip at 360 dp.
  testWidgets('360 dp: short "Staff" title and role chip both fit', (t) async {
    await pumpStaff(
      t,
      location: '/staff',
      role: 'representative',
      size: const Size(360, 780),
      overrides: [repConsoleApiProvider.overrideWithValue(FakeRepConsoleApi())],
    );
    final title = find.byKey(const Key('staff.title'));
    expect(t.widget<Text>(title).data, 'Staff');
    // Test glyphs are square (wider than Mukta/Baloo), so assert layout:
    // title visible, whole chip before the icon-only Sign out.
    expect(t.getSize(title).width, greaterThan(0));
    expect(find.text('Representative'), findsOneWidget);
    final chip = t.getRect(find.byKey(const Key('staff.roleChip')));
    final signOut = t.getRect(find.byKey(const Key('staff.signOut')));
    expect(chip.right, lessThanOrEqualTo(signOut.left));
    expect(find.byTooltip('Sign out'), findsOneWidget);
    expect(find.text('Sign out'), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('wide layout keeps the full "Saarthee staff" title', (t) async {
    await pumpStaff(t, location: '/staff');
    expect(
      t.widget<Text>(find.byKey(const Key('staff.title'))).data,
      'Saarthee staff',
    );
  });
}
