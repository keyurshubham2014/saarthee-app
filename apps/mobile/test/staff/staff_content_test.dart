// T-12-19 (AC-9): staff service form validation (https link, required en/gu,
// numbered steps), SLUG_TAKEN from the server, and the forbidden state.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/api/app_error.dart';
import 'package:saarthee/features/staff/content/data/staff_content_api.dart';

import '../services/harness.dart';

class FakeStaffApi implements StaffContentApi {
  final List<Map<String, Object?>> created = [];
  bool slugTaken = false;

  @override
  Future<Map<String, dynamic>> createService(Map<String, Object?> body) async {
    if (slugTaken) throw const AppError(code: 'SLUG_TAKEN', statusCode: 409);
    created.add(body);
    return {'id': 'new', ...body};
  }

  @override
  Future<List<Map<String, dynamic>>> services({
    bool brokenOnly = false,
  }) async => [
    {
      'id': 's1',
      'slug': 'rti',
      'nameEn': 'RTI',
      'category': 'information',
      'linkOk': false,
      'linkStatusCode': 404,
      'isActive': true,
    },
    if (!brokenOnly)
      {
        'id': 's2',
        'slug': 'brts',
        'nameEn': 'BRTS',
        'category': 'transport',
        'linkOk': true,
        'isActive': true,
      },
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _fill(WidgetTester t, String name, String value) async {
  final f = find.descendant(
    of: find.byKey(Key('form.$name')),
    matching: find.byType(EditableText),
  );
  await t.ensureVisible(
    f.evaluate().isEmpty ? find.byKey(Key('form.$name')) : f,
  );
  await t.enterText(find.byKey(Key('form.$name')), value);
}

void main() {
  testWidgets('T-12-19 form blocks bad input, then creates the service', (
    t,
  ) async {
    final api = FakeStaffApi();
    await pumpServices(
      t,
      location: '/staff/services/new',
      role: 'admin',
      staffApi: api,
      size: const Size(1000, 2400),
    );
    await t.tap(find.byKey(const Key('form.save')));
    await t.pump();
    expect(find.byKey(const Key('form.errors')), findsOneWidget);
    expect(find.text('Required.'), findsWidgets);
    expect(api.created, isEmpty);

    await _fill(t, 'slug', 'marriage-registration');
    await _fill(t, 'nameEn', 'Marriage registration');
    await _fill(t, 'nameGu', 'લગ્ન નોંધણી');
    await _fill(t, 'department', 'Marriage Registration');
    await _fill(t, 'departmentGu', 'લગ્ન નોંધણી વિભાગ');
    await _fill(t, 'summaryEn', 'Register a marriage.');
    await _fill(t, 'summaryGu', 'લગ્ન નોંધાવો.');
    await _fill(t, 'howToEn', 'Open the page');
    await _fill(t, 'howToGu', '1. પેજ ખોલો.');
    await _fill(t, 'url', 'http://insecure.example');
    await t.tap(find.byKey(const Key('form.save')));
    await t.pump();
    expect(find.text('Use a full https:// link.'), findsWidgets);
    expect(
      find.text('Write each step on its own line as "1. …".'),
      findsWidgets,
    );
    expect(api.created, isEmpty);

    await _fill(t, 'howToEn', '1. Open the page.\n2. Book a slot.');
    await t.pump();
    expect(find.byKey(const Key('form.howToEn.preview')), findsOneWidget);
    expect(find.text('2. Book a slot.'), findsOneWidget);
    await _fill(t, 'url', 'https://ahmedabadcity.gov.in/');
    api.slugTaken = true;
    await t.tap(find.byKey(const Key('form.save')));
    await t.pump();
    await t.pump();
    expect(find.text('That short name is already used.'), findsWidgets);

    api.slugTaken = false;
    await t.tap(find.byKey(const Key('form.save')));
    await t.pump();
    await t.pump();
    expect(api.created.single, containsPair('slug', 'marriage-registration'));
    expect(api.created.single, containsPair('sortOrder', 100));
    expect(api.created.single, containsPair('visitWardOffice', false));
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets(
    'T-12-19 citizens see "You don\'t have access"; moderators read the list without edit',
    (t) async {
      await pumpServices(
        t,
        location: '/staff/services/new',
        role: 'citizen',
        staffApi: FakeStaffApi(),
      );
      expect(find.byKey(const Key('staff.forbidden')), findsOneWidget);
      expect(find.text("You don't have access to this page."), findsOneWidget);

      await pumpServices(
        t,
        location: '/staff/services/new',
        role: 'moderator',
        staffApi: FakeStaffApi(),
      );
      expect(find.byKey(const Key('staff.forbidden')), findsOneWidget);

      await pumpServices(
        t,
        location: '/staff/services',
        role: 'moderator',
        staffApi: FakeStaffApi(),
      );
      expect(find.byKey(const Key('staff.service.rti')), findsOneWidget);
      expect(find.textContaining('Broken 404'), findsOneWidget);
      expect(find.byKey(const Key('staff.services.new')), findsNothing);
      expect(find.byTooltip('Check link now'), findsNWidgets(2));
      expect(find.byTooltip('Edit'), findsNothing);
    },
  );
}
