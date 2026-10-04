// T-12-18 (AC-11, AC-12): Home tip card show/dismiss, drives section,
// shortcuts; My Ward services; placeholders P-03 and P-08 gone.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/features/initiatives/data/initiatives_repository.dart';
import 'package:saarthee/features/services/data/service_models.dart';
import 'package:saarthee/features/services/data/services_repository.dart';
import 'package:saarthee/features/services/presentation/home_services_section.dart';
import 'package:saarthee/features/services/presentation/ward_services_section.dart';

import '../helpers/app.dart';
import '../helpers/fake_wards.dart';
import 'fakes.dart';
import 'harness.dart';

const _tip = ServiceTip(
  id: 't1',
  titleEn: 'Property tax early-payment rebate',
  titleGu: 'વળતર',
  bodyEn: "Check the official page for this year's dates.",
  bodyGu: 'તારીખો જુઓ.',
  serviceSlug: 'property-tax-pay',
);

FakeServicesRepository _services({List<ServiceTip> tips = const [_tip]}) =>
    FakeServicesRepository(
      items: [
        svc('property-tax-pay'),
        svc('rti', wardOffice: true, online: false),
        svc('civic-centres', wardOffice: true, online: false),
      ],
      details: {
        'property-tax-pay': detail(svc('property-tax-pay')),
        'rti': detail(svc('rti', wardOffice: true)),
      },
      tipList: tips,
    );

Widget _home() =>
    ListView(children: const [HomeServicesSection(), WardServicesSection()]);

void main() {
  testWidgets(
    'T-12-18 tip card opens its service and stays hidden once dismissed',
    (t) async {
      final router = await pumpServices(
        t,
        location: '/',
        home: _home(),
        size: const Size(400, 4000),
        services: _services(),
        initiatives: FakeInitiativesRepository([
          drive(id: 'a'),
          drive(id: 'b'),
          drive(id: 'c'),
        ]),
        prefs: homeWardPrefs(paldi),
      );
      expect(find.byKey(const Key('home.tip.t1')), findsOneWidget);
      expect(find.text('Property tax early-payment rebate'), findsOneWidget);
      // Next 2 drives on Home; next 3 in My Ward.
      expect(find.byKey(const Key('initiative.card.a')), findsNWidgets(2));
      expect(find.byKey(const Key('initiative.card.c')), findsOneWidget);
      for (final k in ['ptax', 'birth', 'kankaria', 'all']) {
        expect(find.byKey(Key('home.shortcut.$k')), findsOneWidget);
      }

      await t.tap(find.byKey(const Key('home.tip.open')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('service.detail')), findsOneWidget);
      expect(find.text('Pay property tax'), findsWidgets);
      router.pop();
      await t.pumpAndSettle();

      await t.tap(find.byKey(const Key('home.tip.dismiss')));
      await t.pump();
      expect(find.byKey(const Key('home.tip.t1')), findsNothing);
    },
  );

  testWidgets(
    'T-12-18 dismissed tip stays hidden after restart; no tip → no card; no drives → section hidden',
    (t) async {
      await pumpServices(
        t,
        location: '/',
        home: _home(),
        services: _services(),
        prefs: {
          ...homeWardPrefs(paldi),
          ServicesPrefKeys.dismissedTips: ['t1'],
        },
      );
      expect(find.byKey(const Key('home.tip.t1')), findsNothing);
      expect(find.byKey(const Key('home.drives.seeAll')), findsNothing);

      await pumpServices(
        t,
        location: '/',
        home: _home(),
        services: _services(tips: const []),
      );
      expect(find.byKey(const Key('home.tip.t1')), findsNothing);
      expect(find.byKey(const Key('service.setWard')), findsOneWidget);
    },
  );

  testWidgets(
    'T-12-18 My Ward lists ward-office services with the office card',
    (t) async {
      await pumpServices(
        t,
        location: '/',
        home: _home(),
        services: _services(),
        prefs: homeWardPrefs(paldi),
      );
      await t.scrollUntilVisible(
        find.byKey(const Key('myWard.allServices')),
        200,
      );
      expect(find.byKey(const Key('services.row.rti')), findsOneWidget);
      expect(
        find.byKey(const Key('services.row.civic-centres')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('services.row.property-tax-pay')),
        findsNothing,
      );
      expect(find.byKey(const Key('service.wardOffice')), findsOneWidget);
    },
  );

  testWidgets('T-12-18 the app no longer shows placeholders P-03 and P-08', (
    t,
  ) async {
    await pumpApp(
      t,
      prefs: onboardedPrefs(),
      overrides: [
        servicesRepositoryProvider.overrideWithValue(_services()),
        initiativesRepositoryProvider.overrideWithValue(
          FakeInitiativesRepository([drive()]),
        ),
      ],
    );
    expect(
      find.byKey(const Key('home.servicesSection'), skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('placeholder.P-03'), skipOffstage: false),
      findsNothing,
    );
    await t.tap(find.text('My Ward').last);
    await t.pumpAndSettle();
    expect(
      find.byKey(const Key('myWard.servicesSection'), skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('placeholder.P-08'), skipOffstage: false),
      findsNothing,
    );
  });
}
