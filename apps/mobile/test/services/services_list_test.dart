// T-12-15 (AC-2): /services list — chips, search (en + gu), badges, offline
// cache, empty state, independence banner.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/api/app_error.dart';

import 'fakes.dart';
import 'harness.dart';

final _items = [
  svc('property-tax-pay'),
  svc('property-tax-bill', nameEn: 'See your property tax bill', nameGu: 'મિલકત વેરા બિલ'),
  svc('rti', category: 'information', nameEn: 'Right to Information', nameGu: 'માહિતી અધિકાર', online: false, wardOffice: true),
  svc('kankaria-tickets', category: 'leisure', nameEn: 'Kankaria Lakefront tickets', nameGu: 'કાંકરિયા ટિકિટ'),
];

Finder _row(String slug) => find.byKey(Key('services.row.$slug'));

void main() {
  testWidgets('T-12-15 chips filter by category, search matches en and gu, badges show', (t) async {
    await pumpServices(t, location: '/services', services: FakeServicesRepository(items: _items));
    expect(find.byKey(const Key('services.independence')), findsOneWidget);
    expect(find.text("Independent guide. Links open AMC's official websites."), findsOneWidget);
    for (final s in _items) {
      expect(_row(s.slug), findsOneWidget);
    }
    expect(find.descendant(of: _row('rti'), matching: find.byKey(const Key('services.badge.wardOffice'))), findsOneWidget);
    expect(find.descendant(of: _row('rti'), matching: find.byKey(const Key('services.badge.online'))), findsNothing);
    expect(find.descendant(of: _row('property-tax-pay'), matching: find.byKey(const Key('services.badge.online'))), findsOneWidget);

    await t.tap(find.byKey(const Key('services.chip.tax')));
    await t.pump();
    expect(_row('rti'), findsNothing);
    expect(_row('property-tax-pay'), findsOneWidget);

    await t.enterText(find.byKey(const Key('services.search')), 'bill');
    await t.pump();
    expect(_row('property-tax-pay'), findsNothing);
    expect(_row('property-tax-bill'), findsOneWidget);

    await t.tap(find.byKey(const Key('services.chip.all')));
    await t.enterText(find.byKey(const Key('services.search')), 'કાંકરિયા');
    await t.pump();
    expect(_row('kankaria-tickets'), findsOneWidget);
    expect(_row('property-tax-bill'), findsNothing);

    await t.enterText(find.byKey(const Key('services.search')), 'zzz');
    await t.pump();
    expect(find.byKey(const Key('services.empty')), findsOneWidget);
    expect(find.text('No service matches “zzz”.'), findsOneWidget);
  });

  testWidgets('T-12-15 offline: cached list with the offline banner; no cache → offline state', (t) async {
    await pumpServices(t, location: '/services', services: FakeServicesRepository(items: _items, fromCache: true));
    expect(find.byKey(const Key('services.offline')), findsOneWidget);
    expect(_row('rti'), findsOneWidget);
  });

  testWidgets('T-12-15 error without cache shows Try again', (t) async {
    await pumpServices(
      t,
      location: '/services',
      services: FakeServicesRepository(listError: const AppError(code: 'INTERNAL_ERROR', statusCode: 500)),
    );
    await t.pump(const Duration(milliseconds: 50));
    expect(find.text("We couldn't load services."), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
