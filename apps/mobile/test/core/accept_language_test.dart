// Every API request carries the app language (not the phone's) so
// server-composed text comes back in Gujarati; an explicit header wins.
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/api/api_client.dart';
import 'package:saarthee/core/settings/app_settings.dart';
import 'package:saarthee/core/settings/locale_controller.dart';
import 'package:saarthee/core/settings/preference_sync.dart';

import '../helpers/app.dart';
import '../helpers/motion.dart';

class _Adapter implements HttpClientAdapter {
  final List<String?> langs = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    langs.add(o.headers['Accept-Language'] as String?);
    return ResponseBody.fromString(
      jsonEncode({}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('Accept-Language follows the app language', () async {
    final prefs = await testPrefs(onboardedPrefs(language: 'gu'));
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        preferenceSyncProvider.overrideWithValue(FakePreferenceSync()),
      ],
    );
    addTearDown(c.dispose);
    final adapter = _Adapter();
    final dio = c.read(dioProvider)..httpClientAdapter = adapter;
    await dio.get<Object>('/x');
    await c.read(localeProvider.notifier).setLanguage('en');
    await dio.get<Object>('/x');
    await dio.get<Object>(
      '/x',
      options: Options(headers: {'Accept-Language': 'gu'}),
    );
    expect(adapter.langs, ['gu', 'en', 'gu']);
  });
}
