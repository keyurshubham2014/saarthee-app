// Session interceptor (TASK-04 §5.4 session handling): Bearer added,
// TOKEN_EXPIRED → one silent renewal + retry, TOKEN_REVOKED → signed out.
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/features/auth/data/session_interceptor.dart';

class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this.responses);

  final List<(int, Map<String, Object?>)> responses;
  final List<String?> authHeaders = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async {
    authHeaders.add(o.headers['Authorization'] as String?);
    final (status, body) = responses.removeAt(0);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, Object?> _err(String code) => {
  'error': {'code': code},
};

({Dio dio, _ScriptedAdapter http, List<String> events}) _setUp(
  List<(int, Map<String, Object?>)> responses, {
  String? renewed = 'new-token',
}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test'));
  final http = _ScriptedAdapter(responses);
  dio.httpClientAdapter = http;
  final events = <String>[];
  var token = 'old-token';
  dio.interceptors.add(
    SessionInterceptor(
      dio: dio,
      currentToken: () => token,
      renew: () async {
        events.add('renew');
        if (renewed != null) token = renewed;
        return renewed;
      },
      onSignedOut: () async => events.add('signedOut'),
    ),
  );
  return (dio: dio, http: http, events: events);
}

void main() {
  test(
    'adds Bearer to citizen calls, never to /admin or the exchange',
    () async {
      final s = _setUp([(200, {}), (200, {}), (200, {})]);
      await s.dio.get<dynamic>('/me');
      await s.dio.get<dynamic>('/admin/complaints');
      await s.dio.post<dynamic>('/auth/firebase');
      expect(s.http.authHeaders, ['Bearer old-token', null, null]);
    },
  );

  test('TOKEN_EXPIRED → renew once and retry with the new token', () async {
    final s = _setUp([
      (401, _err('TOKEN_EXPIRED')),
      (200, {'ok': true}),
    ]);
    final res = await s.dio.get<dynamic>('/me');
    expect(res.data, {'ok': true});
    expect(s.events, ['renew']);
    expect(s.http.authHeaders, ['Bearer old-token', 'Bearer new-token']);
  });

  test('failed renewal → signed out, error passed on', () async {
    final s = _setUp([(401, _err('TOKEN_EXPIRED'))], renewed: null);
    await expectLater(s.dio.get<dynamic>('/me'), throwsA(isA<DioException>()));
    expect(s.events, ['renew', 'signedOut']);
  });

  test('TOKEN_REVOKED → signed out without renewal', () async {
    final s = _setUp([(401, _err('TOKEN_REVOKED'))]);
    await expectLater(s.dio.get<dynamic>('/me'), throwsA(isA<DioException>()));
    expect(s.events, ['signedOut']);
  });
}
