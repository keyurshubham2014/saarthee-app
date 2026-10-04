// W-FIX-ALR: the inbox must call `GET /me/notifications` on open and on
// pull-to-refresh (also after a late session restore / sign-in), render the
// rows, update the bell badge, and swipe-to-read must `POST .../read`.
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/api/api_client.dart';
import 'package:saarthee/core/settings/app_settings.dart';
import 'package:saarthee/core/wards/wards_repository.dart';
import 'package:saarthee/features/alerts/data/alerts_api.dart';
import 'package:saarthee/features/auth/application/session_controller.dart';
import 'package:saarthee/features/auth/data/account_api.dart';
import 'package:saarthee/features/auth/data/auth_gateway.dart';
import 'package:saarthee/features/auth/data/secure_store.dart';

import '../auth/fakes.dart';
import '../helpers/app.dart';
import '../helpers/fake_wards.dart';
import 'alert_fakes.dart';

/// Records every HTTP request and answers with canned JSON.
class _Adapter implements HttpClientAdapter {
  final List<String> calls = [];
  List<Map<String, dynamic>> items = [];

  int get _unread => items.where((i) => i['readAt'] == null).length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add('${o.method} ${o.path}');
    Object body = {'items': <Object>[]};
    if (o.path == '/me/notifications') {
      body = {'items': items, 'unreadCount': _unread};
    } else if (o.path == '/me/notifications/read') {
      final ids = (o.data as Map)['ids'] as List?;
      final now = DateTime.now().toUtc().toIso8601String();
      for (final i in items) {
        if (ids == null || ids.contains(i['id'])) i['readAt'] ??= now;
      }
      body = {'unreadCount': _unread};
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}

  int count(String call) => calls.where((c) => c == call).length;
}

/// Starts signed out (not yet restored), like the real session at launch.
class _LateSession extends SessionController {
  @override
  SessionState build() => const SessionState();

  void signIn() =>
      state = const SessionState(token: 'session-jwt', restored: true);
}

const _get = 'GET /me/notifications';

Future<_Adapter> _pump(
  WidgetTester t, {
  bool late = false,
  bool real = false,
}) async {
  final adapter = _Adapter()..items = [inboxJson('n1'), inboxJson('n2')];
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
    ..httpClientAdapter = adapter;
  await pumpApp(
    t,
    prefs: {
      ...onboardedPrefs(),
      PrefKeys.homeWard: jsonEncode(paldi.toPrefsJson()),
    },
    overrides: [
      dioProvider.overrideWithValue(dio),
      alertsApiProvider.overrideWith((ref) => AlertsApi(ApiClient(dio))),
      if (real) ...[
        secureStoreProvider.overrideWithValue(
          MemorySecureStore()..values[SecureKeys.sessionToken] = 'session-jwt',
        ),
        authGatewayProvider.overrideWithValue(FakeAuthGateway()),
        accountApiProvider.overrideWithValue(FakeAccountApi()),
      ] else
        sessionProvider.overrideWith(late ? _LateSession.new : FakeSession.new),
      wardsRepositoryProvider.overrideWithValue(FakeWardsRepository()),
    ],
  );
  return adapter;
}

Future<void> _openInbox(WidgetTester t) async {
  await t.tap(find.byKey(const Key('nav.3')));
  await t.pumpAndSettle();
  await t.tap(find.byKey(const ValueKey('inboxBell')));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('open requests GET /me/notifications and renders rows', (
    t,
  ) async {
    final api = await _pump(t);
    await _openInbox(t);
    expect(api.count(_get), greaterThanOrEqualTo(1));
    expect(find.byKey(const ValueKey('inbox.n1')), findsOneWidget);
    expect(find.byKey(const ValueKey('inbox.n2')), findsOneWidget);
  });

  testWidgets('late sign-in: opening the inbox still fetches', (t) async {
    final api = await _pump(t, late: true);
    await t.tap(find.byKey(const Key('nav.3')));
    await t.pumpAndSettle();
    final c = ProviderScope.containerOf(t.element(find.byType(Scaffold).first));
    (c.read(sessionProvider.notifier) as _LateSession).signIn();
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('inboxBell')));
    await t.pumpAndSettle();
    expect(api.count(_get), greaterThanOrEqualTo(1));
    expect(find.byKey(const ValueKey('inbox.n1')), findsOneWidget);
  });

  testWidgets('sign-in while the bell is offstage: inbox still fetches', (
    t,
  ) async {
    final api = await _pump(t, late: true);
    await t.tap(find.byKey(const Key('nav.3')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('nav.0')));
    await t.pumpAndSettle();
    final c = ProviderScope.containerOf(t.element(find.byType(Scaffold).first));
    (c.read(sessionProvider.notifier) as _LateSession).signIn();
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('nav.3')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('inboxBell')));
    await t.pumpAndSettle();
    expect(api.count(_get), greaterThanOrEqualTo(1));
    expect(find.byKey(const ValueKey('inbox.n1')), findsOneWidget);
  });

  testWidgets('real session restored from secure storage: inbox fetches', (
    t,
  ) async {
    final api = await _pump(t, real: true);
    await _openInbox(t);
    expect(api.count(_get), greaterThanOrEqualTo(1));
    expect(find.byKey(const ValueKey('inbox.n1')), findsOneWidget);
  });

  testWidgets('re-open refetches: a row created after the first load shows', (
    t,
  ) async {
    final api = await _pump(t);
    api.items = [];
    await _openInbox(t);
    expect(find.byKey(const ValueKey('inboxEmpty')), findsOneWidget);
    final before = api.count(_get);
    await t.pageBack();
    await t.pumpAndSettle();
    api.items = [inboxJson('n9')];
    await t.tap(find.byKey(const ValueKey('inboxBell')));
    await t.pumpAndSettle();
    expect(api.count(_get), before + 1);
    expect(find.byKey(const ValueKey('inbox.n9')), findsOneWidget);
  });

  testWidgets('pull-to-refresh on the empty state refetches and renders', (
    t,
  ) async {
    final api = await _pump(t);
    api.items = [];
    await _openInbox(t);
    final before = api.count(_get);
    api.items = [inboxJson('n7')];
    await t.fling(
      find.byKey(const ValueKey('inboxEmpty')),
      const Offset(0, 400),
      1000,
    );
    await t.pumpAndSettle();
    expect(api.count(_get), before + 1);
    expect(find.byKey(const ValueKey('inbox.n7')), findsOneWidget);
  });

  testWidgets('pull-to-refresh on the list refetches', (t) async {
    final api = await _pump(t);
    await _openInbox(t);
    final before = api.count(_get);
    await t.fling(
      find.byKey(const ValueKey('inbox.n1')),
      const Offset(0, 400),
      1000,
    );
    await t.pumpAndSettle();
    expect(api.count(_get), before + 1);
  });

  testWidgets('empty state is centred horizontally, in the upper middle', (
    t,
  ) async {
    final api = await _pump(t);
    api.items = [];
    await _openInbox(t);
    final screen = t.getRect(find.byType(Scaffold).last);
    final icon = t.getRect(find.byKey(const Key('emptyState.icon')));
    final message = t.getRect(find.text('No notifications yet.'));
    expect(icon.center.dx, moreOrLessEquals(screen.center.dx, epsilon: 1));
    expect(message.center.dx, moreOrLessEquals(screen.center.dx, epsilon: 1));
    expect(icon.top, greaterThan(screen.top + screen.height * 0.15));
    expect(message.bottom, lessThan(screen.center.dy));
  });

  testWidgets('bell badge follows the load; swipe POSTs read', (t) async {
    final api = await _pump(t);
    await _openInbox(t);
    await t.pageBack();
    await t.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('inboxBell')),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
    await t.tap(find.byKey(const ValueKey('inboxBell')));
    await t.pumpAndSettle();
    await t.drag(
      find.byKey(const ValueKey('inboxRow.n1')),
      const Offset(-300, 0),
    );
    await t.pumpAndSettle();
    expect(api.count('POST /me/notifications/read'), 1);
    await t.pageBack();
    await t.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('inboxBell')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
  });
}
