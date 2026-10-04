// T-12-16 (AC-3, AC-4): service detail — numbered steps, ward office card or
// set-ward prompt, broken-link banner, external launch with the caption.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/features/services/application/external_links.dart';
import 'package:saarthee/features/services/data/service_models.dart';

import '../helpers/fake_wards.dart';
import 'fakes.dart';
import 'harness.dart';

const _office = WardOffice(
  wardId: 'w12',
  number: 12,
  nameEn: 'Paldi',
  nameGu: 'પાલડી',
  addressEn: 'Paldi Ward Office, Ashram Road',
  phone: '07926500000',
);

void main() {
  testWidgets(
    'T-12-16 steps, ward office with Call, source line and external launch',
    (t) async {
      final rti = svc(
        'rti',
        category: 'information',
        online: false,
        wardOffice: true,
      );
      final repo = FakeServicesRepository(
        details: {'rti': detail(rti, office: _office)},
      );
      final launcher = LaunchRecorder();
      await pumpServices(
        t,
        location: '/services/rti',
        services: repo,
        launcher: launcher,
        prefs: homeWardPrefs(paldi),
      );

      expect(repo.detailWards, contains('w12'));
      expect(find.byKey(const Key('service.step.0')), findsOneWidget);
      expect(find.text('Open the page.'), findsOneWidget);
      expect(find.text('Enter your number.'), findsOneWidget);
      expect(find.text('1.'), findsNothing);
      expect(find.byKey(const Key('service.brokenLink')), findsNothing);
      expect(
        find.text(
          'Opens ahmedabadcity.gov.in. Saarthee is an independent app, not run by AMC.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Source: Amdavad Municipal Corporation website · Last checked',
        ),
        findsOneWidget,
      );

      await t.scrollUntilVisible(
        find.byKey(const Key('service.wardOffice')),
        200,
      );
      expect(find.text('Paldi Ward Office, Ashram Road'), findsOneWidget);
      await t.tap(find.byKey(const Key('service.call')));
      await t.pump();
      expect(launcher.calls.last.$1.toString(), 'tel:07926500000');

      await t.scrollUntilVisible(find.byKey(const Key('service.open')), -200);
      await t.tap(find.byKey(const Key('service.open')));
      await t.pump();
      expect(
        launcher.calls.last.$1.toString(),
        'https://ahmedabadcity.gov.in/PTAX/DuesSearch',
      );
      expect(
        launcher.calls.every((c) => c.$2 == LaunchMode.externalApplication),
        isTrue,
      );
    },
  );

  testWidgets(
    'T-12-16 no home ward → set-ward prompt; broken link → warning; launch failure → message',
    (t) async {
      final rti = svc(
        'rti',
        category: 'information',
        online: false,
        wardOffice: true,
        linkOk: false,
      );
      final launcher = LaunchRecorder()..result = false;
      await pumpServices(
        t,
        location: '/services/rti',
        services: FakeServicesRepository(
          details: {
            'rti': detail(rti, lastCheckedAt: DateTime.utc(2026, 10, 1)),
          },
        ),
        launcher: launcher,
      );
      expect(find.byKey(const Key('service.brokenLink')), findsOneWidget);
      expect(
        find.textContaining(
          "We couldn't open this page when we last checked on",
        ),
        findsOneWidget,
      );
      await t.scrollUntilVisible(find.byKey(const Key('service.setWard')), 200);
      expect(
        find.text('Set your home ward to see your ward office'),
        findsOneWidget,
      );

      await t.scrollUntilVisible(find.byKey(const Key('service.open')), -200);
      await t.tap(find.byKey(const Key('service.open')));
      await t.pump();
      await t.pump();
      expect(find.text("Couldn't open the link."), findsOneWidget);
      await t.pump(const Duration(seconds: 5));
    },
  );

  testWidgets('T-12-16 unknown service → "no longer listed"', (t) async {
    await pumpServices(
      t,
      location: '/services/gone',
      services: FakeServicesRepository(),
    );
    await t.pump();
    expect(find.text('This service is no longer listed.'), findsOneWidget);
  });
}
