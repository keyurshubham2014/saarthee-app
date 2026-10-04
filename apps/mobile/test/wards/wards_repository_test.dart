import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/settings/app_settings.dart';
import 'package:saarthee/core/wards/ward.dart';
import 'package:saarthee/core/wards/wards_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Answers each request with the next scripted `(status, body)`, or a
/// connection error when the script entry is null.
class _ScriptedAdapter implements HttpClientAdapter {
  final script = <(int, Object)?>[];
  final paths = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(
      '${options.path}?${Uri(queryParameters: options.queryParameters.map((k, v) => MapEntry(k, '$v'))).query}',
    );
    final next = script.removeAt(0);
    if (next == null) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      );
    }
    return ResponseBody.fromString(
      jsonEncode(next.$2),
      next.$1,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _fixture() =>
    jsonDecode(File('test/fixtures/wards.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  late _ScriptedAdapter adapter;
  late SharedPreferences prefs;
  late ApiWardsRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    adapter = _ScriptedAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test/api/v1'))
      ..httpClientAdapter = adapter;
    repo = ApiWardsRepository(dio: dio, prefs: prefs, languageCode: 'gu');
  });

  Map<String, dynamic> cache() =>
      jsonDecode(prefs.getString(PrefKeys.wardsCache)!) as Map<String, dynamic>;

  group('F-02-02 listWards', () {
    test('maps the real 48-ward fixture with nested zones', () async {
      final body = _fixture();
      adapter.script.add((200, body));
      final r = await repo.listWards();
      expect(r.fromCache, isFalse);
      expect(r.wards, hasLength(48));
      expect(r.boundaryVersion, body['boundaryVersion']);
      expect(r.wards.map((w) => w.number), [for (var i = 1; i <= 48; i++) i]);
      final paldi = r.wards.firstWhere((w) => w.number == 30);
      expect(paldi.nameEn, 'Paldi');
      expect(paldi.nameGu, 'પાલડી');
      expect(paldi.zone.code, 'west');
      expect(paldi.zone.id, isNotEmpty);
      expect(paldi.zone.nameGu, 'પશ્ચિમ ઝોન');
      expect(r.wards.map((w) => w.zone.code).toSet(), hasLength(7));
    });

    test('writes the cache with boundaryVersion', () async {
      adapter.script.add((200, _fixture()));
      await repo.listWards();
      final c = cache();
      expect(c['boundaryVersion'], _fixture()['boundaryVersion']);
      expect(c['items'], hasLength(48));
      expect(c['fetchedAt'], isA<String>());
    });

    test('same version and wards → cache left as is', () async {
      adapter.script.add((200, _fixture()));
      await repo.listWards();
      final first = prefs.getString(PrefKeys.wardsCache);
      adapter.script.add((200, _fixture()));
      await repo.listWards();
      expect(prefs.getString(PrefKeys.wardsCache), first);
    });

    test('a different boundaryVersion replaces the cache', () async {
      adapter.script.add((200, _fixture()));
      await repo.listWards();
      final next = _fixture()
        ..['boundaryVersion'] = 'opencity-amc-wards-2099-01'
        ..['items'] = (_fixture()['items'] as List).take(47).toList();
      adapter.script.add((200, next));
      final r = await repo.listWards();
      expect(r.boundaryVersion, 'opencity-amc-wards-2099-01');
      expect(cache()['boundaryVersion'], 'opencity-amc-wards-2099-01');
      expect(cache()['items'], hasLength(47));
    });

    test('offline after one load → cached list, fromCache true', () async {
      adapter.script.add((200, _fixture()));
      await repo.listWards();
      adapter.script.addAll([null, null]); // first try + one retry
      final r = await repo.listWards();
      expect(r.fromCache, isTrue);
      expect(r.wards, hasLength(48));
      expect(r.boundaryVersion, _fixture()['boundaryVersion']);
    });

    test(
      'offline with a pre-v2.2 cache (no boundaryVersion) still works',
      () async {
        await prefs.setString(
          PrefKeys.wardsCache,
          jsonEncode({'items': _fixture()['items']}),
        );
        adapter.script.addAll([null, null]);
        final r = await repo.listWards();
        expect(r.fromCache, isTrue);
        expect(r.boundaryVersion, isNull);
        expect(r.wards, hasLength(48));
      },
    );

    test('offline and no cache → unavailable', () async {
      adapter.script.addAll([null, null]);
      await expectLater(
        repo.listWards(),
        throwsA(
          isA<WardException>().having(
            (e) => e.failure,
            'failure',
            WardFailure.unavailable,
          ),
        ),
      );
    });

    test('an empty list never replaces a good cache', () async {
      adapter.script.add((200, _fixture()));
      await repo.listWards();
      adapter.script.add((200, {'items': <Object>[], 'boundaryVersion': 'x'}));
      final r = await repo.listWards();
      expect(r.fromCache, isTrue);
      expect(cache()['items'], hasLength(48));
    });
  });

  group('F-02-02 locate', () {
    Map<String, dynamic> locateBody({
      required String match,
      required bool confirm,
      required num distanceM,
      bool nestedZone = true,
    }) {
      final ward = Map<String, dynamic>.from(
        (_fixture()['items'] as List).firstWhere((w) => w['number'] == 30)
            as Map,
      );
      final zone = ward['zone'];
      if (!nestedZone) ward.remove('zone');
      return {
        'ward': ward,
        'zone': zone,
        'match': match,
        'confirm': confirm,
        'distanceM': distanceM,
        'boundaryVersion': _fixture()['boundaryVersion'],
      };
    }

    Matcher failure(WardFailure f) =>
        throwsA(isA<WardException>().having((e) => e.failure, 'failure', f));

    test('inside → match inside, confirm false, 6 dp query', () async {
      adapter.script.add((
        200,
        locateBody(match: 'inside', confirm: false, distanceM: 0),
      ));
      final r = await repo.locate(23.0120001234, 72.56);
      expect(adapter.paths.single, '/geo/locate?lat=23.012000&lng=72.560000');
      expect(r.ward.number, 30);
      expect(r.ward.zone.code, 'west');
      expect(r.match, WardMatch.inside);
      expect(r.confirm, isFalse);
      expect(r.distanceM, 0);
      expect(r.boundaryVersion, _fixture()['boundaryVersion']);
    });

    test(
      'nearest → confirm true with distanceM; zone from top level',
      () async {
        adapter.script.add((
          200,
          locateBody(
            match: 'nearest',
            confirm: true,
            distanceM: 412.4,
            nestedZone: false,
          ),
        ));
        final r = await repo.locate(23.2, 72.4);
        expect(r.match, WardMatch.nearest);
        expect(r.confirm, isTrue);
        expect(r.distanceM, 412);
        expect(r.ward.zone.code, 'west');
        expect(r.ward.zone.nameGu, 'પશ્ચિમ ઝોન');
      },
    );

    test('422 OUTSIDE_SERVICE_AREA → OutsideServiceArea', () async {
      adapter.script.add((
        422,
        {
          'error': {
            'code': 'OUTSIDE_SERVICE_AREA',
            'message': "This place is outside Ahmedabad's municipal wards.",
          },
        },
      ));
      await expectLater(
        repo.locate(23.2156, 72.6369),
        throwsA(
          isA<OutsideServiceArea>().having(
            (e) => e.failure,
            'failure',
            WardFailure.outsideCity,
          ),
        ),
      );
    });

    test('malformed 200 → notFound; offline → unavailable', () async {
      adapter.script.add((200, {'match': 'inside'}));
      await expectLater(repo.locate(23, 72.5), failure(WardFailure.notFound));
      adapter.script.addAll([null, null]);
      await expectLater(
        repo.locate(23, 72.5),
        failure(WardFailure.unavailable),
      );
    });
  });
}
