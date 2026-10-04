// W-10-01 (nav by role, registry hides unlanded items), W-10-02 (responsive
// shell at 1,280 and 360 dp), AC-1 forbidden page and dashboard counts.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/features/staff/shared/staff_shared.dart';
import 'package:saarthee/features/staff/shell/staff_shell.dart';

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
      '/staff/services',
      '/staff/initiatives',
      '/staff/tips',
      '/staff/categories',
      '/staff/users',
      '/staff/settings',
      '/staff/exports',
    ]);
    expect(find.text('Administration'), findsOneWidget);
    expect(find.byKey(const Key('staff.roleChip')), findsOneWidget);
    expect(find.byKey(const Key('staff.brandMark')), findsOneWidget);
    expect(find.text('Admin'), findsWidgets);
    expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets('W-10-01 moderator sees Dashboard, Moderation, Alerts only', (
    t,
  ) async {
    await pumpStaff(t, location: '/staff', role: 'moderator');
    expect(_navRoutes(t), ['/staff', '/staff/moderation', '/staff/alerts']);
  });

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
    expect(
      routes.any(
        (r) =>
            r.contains('representatives') ||
            r.contains('claims') ||
            r.contains('ward'),
      ),
      isFalse,
    );
    expect(staffNavFor('representative'), isEmpty);
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
}
