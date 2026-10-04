// I-14-01 (TASK-14 step 9, AC-2): report → acknowledge → mark fixed →
// verify, end to end against the real API and the Firebase Auth Emulator.
//
// Scenario 1: citizen A reports `roads` in the app (fixture photo, fixed
// GPS in Navrangpura) → done → issue detail "Reported" → a moderator token
// acknowledges and marks fixed through the API → the reopened detail shows
// Fixed → citizen B, 30 m away, answers "Yes, it's fixed" → chip Verified.
// Scenario 2: same chain, then the reporter answers "Still not fixed" →
// chip Reopened. Each scenario asserts exactly one issue for its reporter
// and the expected status `issue_events`.
//
// Run by the integrator (local stack: API on :4000 with the v2 seed, Auth
// Emulator on :9099, emulator-5554):
//   cd apps/mobile && flutter test integration_test/report_to_verify_test.dart \
//     -d emulator-5554 \
//     --dart-define=API_BASE_URL=http://10.0.2.2:4000/api/v1 \
//     --dart-define=AUTH_EMULATOR_HOST=10.0.2.2:9099 --dart-define=APP_ENV=test
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:saarthee/core/capture/evidence_capture.dart';
import 'package:saarthee/features/report/application/report_providers.dart';

import 'support/e2e_app.dart';
import 'support/lifecycle_api.dart';
import 'support/verify_flow.dart';

/// Navrangpura pilot point (prisma/seed/modules/050-issues.ts PILOT_POINTS);
/// override with --dart-define=E2E_LAT / E2E_LNG if the seed moves.
final reportLat = double.parse(
  const String.fromEnvironment('E2E_LAT', defaultValue: '23.0368'),
);
final reportLng = double.parse(
  const String.fromEnvironment('E2E_LNG', defaultValue: '72.5580'),
);

/// A different spot per run (≤ ~90 m north) so earlier runs' roads reports
/// do not all stack on one point; still well inside the ward.
final _jitter = (DateTime.now().millisecondsSinceEpoch % 9) * 10 / 111195;

Fix fixAt(double lat, double lng) =>
    Fix(latitude: lat, longitude: lng, accuracy: 8);

/// Taps [key] once its button is enabled (upload / ward lookup finished).
Future<void> tapWhenEnabled(WidgetTester t, Key key, {int seconds = 30}) async {
  final f = find.byKey(key, skipOffstage: false);
  for (var i = 0; i < seconds * 10; i++) {
    await t.pump(const Duration(milliseconds: 100));
    final buttons = find.descendant(
      of: f,
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
    );
    final b = buttons.evaluate().isEmpty
        ? null
        : buttons.evaluate().first.widget as ButtonStyleButton;
    if (b != null && b.onPressed != null) {
      await t.ensureVisible(find.byKey(key, skipOffstage: false).first);
      await t.pump();
      await t.tap(find.byKey(key).first);
      return;
    }
  }
  throw TestFailure('Timed out waiting for enabled $key');
}

/// Taps [key] if it is on screen (optional prompts: duplicate, ward edge).
Future<void> tapIfShown(WidgetTester t, Key key) async {
  final all = find.byKey(key, skipOffstage: false);
  if (all.evaluate().isEmpty) return;
  await t.ensureVisible(all.first);
  await t.pump();
  await t.tap(find.byKey(key).first);
  await t.pump(const Duration(milliseconds: 500));
}

/// Citizen A's report through the app UI; returns the new issue id.
Future<String> reportInApp(WidgetTester t, ProviderContainer c) async {
  await goTo(t, c, '/report');
  await waitFor(t, find.byKey(const ValueKey('report.tile.roads')));
  await t.tap(find.byKey(const ValueKey('report.tile.roads')));
  // Camera opens on entry (fake), then blur + upload to the real API.
  await waitFor(t, find.byKey(const Key('report.thumb.0')), seconds: 30);
  await tapIfShown(t, const Key('report.ward.yes'));
  await tapWhenEnabled(t, const Key('report.continue'));
  await t.pump(const Duration(seconds: 1));
  await tapIfShown(t, const Key('report.dup.different'));
  await tapIfShown(t, const Key('report.ward.yes'));
  await tapWhenEnabled(t, const Key('report.submit'));
  await waitFor(t, find.byKey(const Key('report.done')), seconds: 30);
  final issue = c.read(lastSubmissionProvider);
  expect(issue, isNotNull, reason: 'done screen has the created issue');
  return issue!.id;
}

/// Status `issue_events` in order (`GET /issues/{id}/events`).
Future<List<String>> statusEvents(Dio dio, String id) async {
  final res = await dio.get<Map<String, dynamic>>(
    '/issues/$id/events',
    queryParameters: {'limit': '50'},
  );
  return [
    for (final e in (res.data!['items'] as List).cast<Map>())
      if (e['toStatus'] != null) e['toStatus'] as String,
  ];
}

Future<int> myIssueCount(Dio dio) async {
  final res = await dio.get<Map<String, dynamic>>(
    '/issues',
    queryParameters: {'mine': 'true', 'limit': '50'},
  );
  return (res.data!['items'] as List).length;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Dio moderator;

  setUpAll(() async {
    expect(apiBase, isNotEmpty, reason: 'pass --dart-define=API_BASE_URL');
    expect(emulatorHost, isNotEmpty, reason: 'pass AUTH_EMULATOR_HOST');
    moderator = userDio(await signIn(moderatorPhone));
  });

  /// Shared chain up to "Fixed" on the reporter's screen.
  Future<(String, String)> reportedThenFixed(WidgetTester t) async {
    final reporterToken = await signIn(newTestPhone());
    final lat = reportLat + _jitter;
    final c = await pumpCitizenApp(
      t,
      token: reporterToken,
      fix: fixAt(lat, reportLng),
    );
    final id = await reportInApp(t, c);
    await goTo(t, c, '/issues/$id');
    await waitFor(t, find.byKey(const ValueKey('statusChip.reported')));

    await setStatus(moderator, id, 'acknowledged');
    await setStatus(moderator, id, 'marked_fixed');

    // The app refreshes the detail on re-entry (as after a push tap).
    await goTo(t, c, '/');
    await goTo(t, c, '/issues/$id');
    await waitFor(t, find.byKey(const ValueKey('statusChip.markedFixed')));
    expect(find.text('Fixed'), findsWidgets, reason: 'timeline shows Fixed');
    expect(await myIssueCount(userDio(reporterToken)), 1);
    return (id, reporterToken);
  }

  Fix thirtyMetresFrom() => fixAt(reportLat + _jitter + 30 / 111195, reportLng);

  testWidgets('A reports, staff fix, neighbour B verifies → Verified', (
    t,
  ) async {
    final (id, _) = await reportedThenFixed(t);
    final b = await signIn(newTestPhone());
    final c = await pumpCitizenApp(t, token: b, fix: thirtyMetresFrom());
    await goTo(t, c, '/issues/$id');
    await waitFor(t, find.byKey(const ValueKey('statusChip.markedFixed')));
    await answer(t, fixed: true);
    await waitFor(t, find.byKey(const ValueKey('statusChip.verified')));
    expect(find.text('Verified'), findsWidgets);
    expect(await lifecycleStatus(moderator, id), 'verified');
    final events = await statusEvents(moderator, id);
    expect(events.where((s) => s != 'reported').toList(), [
      'acknowledged',
      'marked_fixed',
      'verified',
    ]);
  });

  testWidgets('the reporter says "Still not fixed" → Reopened', (t) async {
    final (id, reporter) = await reportedThenFixed(t);
    final c = await pumpCitizenApp(t, token: reporter, fix: thirtyMetresFrom());
    await goTo(t, c, '/issues/$id');
    await waitFor(t, find.byKey(const ValueKey('statusChip.markedFixed')));
    await answer(t, fixed: false);
    await waitFor(t, find.byKey(const ValueKey('statusChip.reopened')));
    expect(await lifecycleStatus(moderator, id), 'reopened');
    final events = await statusEvents(moderator, id);
    expect(events.where((s) => s != 'reported').toList(), [
      'acknowledged',
      'marked_fixed',
      'reopened',
    ]);
  });
}
