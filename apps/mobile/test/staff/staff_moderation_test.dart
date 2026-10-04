// W-10-03 (moderation list states, stale item) and W-10-04 (issue tools:
// reject reasons, merge search, confirm dialogs, mark fixed with an after
// photo).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/api/app_error.dart';
import 'package:saarthee/core/theme/motion.dart';
import 'package:saarthee/features/staff/issues/staff_issue_dialogs.dart';
import 'package:saarthee/features/staff/shared/staff_api.dart';

import 'staff_harness.dart';

Json _item(String id, {List<Json> flags = const []}) => {
  'id': id,
  'title': 'Pothole $id',
  'status': 'reported',
  'visibility': 'public',
  'createdAt': '2030-01-10T05:30:00Z',
  'category': {'slug': 'roads'},
  'ward': {'id': 'w12', 'number': 12, 'nameEn': 'Paldi', 'nameGu': 'પાલડી'},
  'openFlags': flags,
  'photoThumbUrl': null,
};

Json _issue(String id, {String status = 'reported', bool hidden = false}) => {
  'id': id,
  'title': 'Pothole $id',
  'description': 'Deep hole',
  'status': status,
  'visibility': hidden ? 'hidden' : 'public',
  'isSensitive': false,
  'moderatedAt': null,
  'lat': 23.01,
  'lng': 72.56,
  'reporterId': 'u9',
  'category': {
    'id': 'c1',
    'slug': 'roads',
    'nameEn': 'Roads',
    'nameGu': 'રસ્તા',
  },
  'ward': {'id': 'w12', 'number': 12, 'nameEn': 'Paldi', 'nameGu': 'પાલડી'},
  'photos': <Json>[],
  'openFlags': <Json>[],
  'flags': <Json>[],
  'timeline': <Json>[
    {
      'id': 'e1',
      'type': 'status_change',
      'toStatus': 'reported',
      'note': null,
      'createdAt': '2030-01-10T05:30:00Z',
      'hidden': false,
    },
  ],
};

FakeStaffApi _api() => FakeStaffApi()
  ..queues = {
    'sensitive': [_item('i1')],
    'flagged': [
      _item(
        'i2',
        flags: [
          {'reason': 'abusive', 'count': 2},
          {'reason': 'spam', 'count': 1},
        ],
      ),
    ],
  }
  ..issues = {
    'i1': _issue('i1'),
    'i2': _issue('i2'),
    'i3': _issue('i3', status: 'acknowledged'),
  };

/// Lets staff toasts finish (they hold for `toastHold`).
Future<void> _drain(WidgetTester t) async {
  await t.pump(SaartheeMotion.toastHold);
  await t.pumpAndSettle();
}

Future<void> _openTools(WidgetTester t, String id) async {
  await t.tap(find.byKey(Key('moderation.row.$id')));
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'W-10-03 tabs show counts, rows, flag reasons and the empty state',
    (t) async {
      await pumpStaff(
        t,
        location: '/staff/moderation',
        api: _api(),
        size: const Size(1400, 900),
      );
      expect(find.text('Sensitive (1)'), findsOneWidget);
      expect(find.text('Flagged (2)'), findsOneWidget);
      expect(find.byKey(const Key('moderation.row.i1')), findsOneWidget);
      expect(find.byKey(const Key('moderation.pane.empty')), findsOneWidget);
      await t.tap(find.byKey(const Key('moderation.tab.flagged')));
      await t.pumpAndSettle();
      expect(find.textContaining('Abusive or hateful · 2'), findsOneWidget);
      await t.tap(find.byKey(const Key('moderation.tab.out_of_area')));
      await t.pumpAndSettle();
      expect(find.text('Nothing to review here.'), findsOneWidget);
    },
  );

  testWidgets(
    'W-10-03 stale item: "Already handled by another moderator." and the pane closes',
    (t) async {
      final api = _api()
        ..failNext = const AppError(
          code: 'ISSUE_STATE_INVALID',
          statusCode: 409,
        );
      await pumpStaff(
        t,
        location: '/staff/moderation',
        api: api,
        size: const Size(1400, 900),
      );
      await _openTools(t, 'i1');
      expect(find.text('A resident of Paldi'), findsOneWidget);
      await t.tap(find.byKey(const Key('staff.action.reviewed')));
      await t.pump();
      await t.pump();
      expect(
        find.text('Already handled by another moderator.'),
        findsOneWidget,
      );
      await t.pumpAndSettle();
      expect(find.byKey(const Key('moderation.pane.empty')), findsOneWidget);
      await _drain(t);
    },
  );

  testWidgets(
    'W-10-04 "Not accepted…" needs a reason, then a confirm stating the effect',
    (t) async {
      final api = _api();
      await pumpStaff(
        t,
        location: '/staff/issues/i1',
        api: api,
        size: const Size(1280, 1600),
      );
      await t.tap(find.byKey(const Key('staff.action.reject')));
      await t.pumpAndSettle();
      for (final label in [
        'Spam',
        'Duplicate',
        'Outside city wards',
        'About a private person',
        'Not a civic issue',
        'Other reason',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      final ok = t.widget<FilledButton>(
        find.byKey(const Key('staff.reject.ok')),
      );
      expect(ok.onPressed, isNull);
      await t.tap(find.byKey(const Key('staff.reject.spam')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('staff.reject.ok')));
      await t.pumpAndSettle();
      expect(
        find.text(
          'The report will be closed as not accepted and the reporter will be told why.',
        ),
        findsOneWidget,
      );
      await t.tap(find.byKey(const Key('staff.confirm.ok')));
      await t.pumpAndSettle();
      expect(api.calls, contains('reject:i1:spam'));
      await _drain(t);
    },
  );

  testWidgets(
    'W-10-04 "Merge into…" lists nearby reports with distance and a far warning',
    (t) async {
      final api = _api()
        ..candidates = [
          {
            'id': 'i9',
            'title': 'Same pothole',
            'distanceM': 40,
            'farWarning': false,
            'category': {'slug': 'roads'},
          },
          {
            'id': 'i8',
            'title': 'Road broken',
            'distanceM': 320,
            'farWarning': true,
            'category': {'slug': 'roads'},
          },
        ];
      await pumpStaff(
        t,
        location: '/staff/issues/i1',
        api: api,
        size: const Size(1280, 1600),
      );
      await t.tap(find.byKey(const Key('staff.action.merge')));
      await t.pumpAndSettle();
      expect(find.textContaining('40 m away'), findsOneWidget);
      expect(find.textContaining('More than 200 m away'), findsOneWidget);
      await t.tap(find.byKey(const Key('staff.merge.i9')));
      await t.pumpAndSettle();
      expect(
        find.text(
          'This report will be closed and its supporters moved to the other report.',
        ),
        findsOneWidget,
      );
      await t.tap(find.byKey(const Key('staff.confirm.ok')));
      await t.pumpAndSettle();
      expect(api.calls, contains('merge:i1:i9'));
      await _drain(t);
    },
  );

  testWidgets('W-10-04 acknowledge, then mark fixed with an after photo', (
    t,
  ) async {
    final api = _api();
    await pumpStaff(
      t,
      location: '/staff/issues/i1',
      api: api,
      size: const Size(1280, 1600),
      overrides: [
        staffPhotoPickerProvider.overrideWithValue(
          () async => List<int>.filled(10, 1),
        ),
      ],
    );
    await t.tap(find.byKey(const Key('staff.action.acknowledge')));
    await t.pumpAndSettle();
    expect(api.calls, contains('status:i1:acknowledged:'));
    await t.tap(find.byKey(const Key('staff.action.mark_fixed')));
    await t.pumpAndSettle();
    expect(
      find.text('Neighbours will be asked to confirm with a photo.'),
      findsOneWidget,
    );
    await t.tap(find.byKey(const Key('staff.fixed.photo')));
    await t.pumpAndSettle();
    expect(find.text('After photo added'), findsOneWidget);
    await t.tap(find.byKey(const Key('staff.fixed.ok')));
    await t.pumpAndSettle();
    expect(
      api.calls,
      containsAllInOrder(['upload:10', 'status:i1:marked_fixed:photo-1']),
    );
    await _drain(t);
  });
}
