// T-04-22 (AC-12): push tap routes only open allow-listed in-app routes.
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/push/push_messaging.dart';
import 'package:saarthee/core/push/push_route.dart';

void main() {
  test('allow-list accepts in-app issue/alert/initiative/inbox routes', () {
    for (final r in [
      '/issues/abc',
      '/issues/3f2a-91bc',
      '/alerts',
      '/alerts/a1',
      '/initiatives/xyz',
      '/me/notifications',
    ]) {
      expect(safePushRoute(r), r, reason: r);
    }
  });

  test('anything else opens Home', () {
    for (final r in [
      'https://x',
      'https://evil.example/issues/1',
      '/admin',
      '/admin/complaints',
      '//evil',
      '//evil.example/issues/1',
      '/issues/../admin',
      '/issues/a/b',
      '/me/privacy',
      '',
      null,
      42,
    ]) {
      expect(safePushRoute(r), '/', reason: '$r');
    }
  });

  test('topics carry the language suffix; no ward → city only', () {
    expect(pushTopicsFor(language: 'gu', wardNumber: 12), [
      'ward_12__gu',
      'city_all__gu',
    ]);
    expect(pushTopicsFor(language: 'en'), ['city_all__en']);
  });
}
