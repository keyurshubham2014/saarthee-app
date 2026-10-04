import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/wards/ward.dart';
import 'package:saarthee/core/wards/ward_search.dart';
import 'package:saarthee/core/wards/wards_repository.dart';

/// F-02-01 — the same table as the API's T-02-07.
const _sharedCases = '../api/test/fixtures/geo/ward-search-cases.json';

List<Ward> _realWards() => ApiWardsRepository.parseWards(
  jsonDecode(File('test/fixtures/wards.json').readAsStringSync()),
);

void main() {
  group('F-02-01 shared search table', () {
    final table = jsonDecode(
      File(_sharedCases).readAsStringSync(),
    ) as Map<String, dynamic>;
    const zone = Zone(
      id: 'z',
      code: 'west',
      nameEn: 'West',
      nameGu: 'પશ્ચિમ ઝોન',
    );
    final wards = [
      for (final w in table['wards'] as List)
        Ward(
          id: 'w${w['number']}',
          number: w['number'] as int,
          nameEn: w['nameEn'] as String,
          nameGu: w['nameGu'] as String,
          zone: zone,
        ),
    ];
    for (final c in table['cases'] as List) {
      final query = c['query'] as String;
      final expected = (c['expect'] as List).cast<int>();
      test('"$query" → $expected', () {
        final got = [
          for (final g in groupAndFilter(wards, query))
            for (final w in g.wards) w.number,
        ];
        expect(got, expected);
      });
    }
  });

  group('F-02-01 grouping over the real 48 wards', () {
    final wards = _realWards();

    test('empty query → 7 zones in AMC order, 48 wards by number', () {
      final groups = groupAndFilter(wards, '');
      expect(groups.map((g) => g.zone.code), Zone.codeOrder);
      expect(groups.expand((g) => g.wards), hasLength(48));
      for (final g in groups) {
        final numbers = g.wards.map((w) => w.number).toList();
        expect(numbers, [...numbers]..sort());
        expect(g.wards.every((w) => w.zone.id == g.zone.id), isTrue);
      }
    });

    test('keeps only groups with matches', () {
      final nav = groupAndFilter(wards, 'nav');
      expect(nav.map((g) => g.zone.code), ['west']);
      expect(nav.single.wards.map((w) => w.nameEn), [
        'Nava Vadaj',
        'Navrangpura',
      ]);
      expect(groupAndFilter(wards, 'zzz'), isEmpty);
    });

    test('"15" and "૧૫" both find Asarva under Central', () {
      for (final q in ['15', '૧૫', 'વોર્ડ ૧૫', 'Ward no. 15']) {
        final g = groupAndFilter(wards, q);
        expect(g.single.zone.code, 'central', reason: q);
        expect(g.single.wards.single.nameEn, 'Asarva', reason: q);
      }
    });

    test('Gujarati and transliterated names match either script', () {
      expect(groupAndFilter(wards, 'પાલડી').single.wards.single.number, 30);
      expect(groupAndFilter(wards, 'PALDI').single.wards.single.number, 30);
      expect(
        groupAndFilter(
          wards,
          'nava',
        ).expand((g) => g.wards).map((w) => w.nameEn),
        contains('Nava Vadaj'),
      );
    });

    test('Gujarati zone names already carry "ઝોન"', () {
      for (final g in groupAndFilter(wards, '')) {
        expect(g.zone.nameGu, endsWith('ઝોન'));
        expect('ઝોન'.allMatches(g.zone.nameGu), hasLength(1));
      }
    });
  });

  test('unknown zone codes sort after the AMC zones', () {
    const odd = Zone(id: 'x', code: 'airport', nameEn: 'Airport', nameGu: 'એ');
    const central = Zone(
      id: 'c',
      code: 'central',
      nameEn: 'Central',
      nameGu: 'મ',
    );
    final groups = groupAndFilter(const [
      Ward(id: '1', number: 1, nameEn: 'A', nameGu: 'અ', zone: odd),
      Ward(id: '2', number: 2, nameEn: 'B', nameGu: 'બ', zone: central),
    ], '');
    expect(groups.map((g) => g.zone.code), ['central', 'airport']);
  });

  test('toAsciiDigits and WardQuery.parse', () {
    expect(toAsciiDigits('૦૧૨૩૪૫૬૭૮૯'), '0123456789');
    expect(WardQuery.parse('ward'), isA<AllWards>());
    expect((WardQuery.parse(' નં. ૭ ') as WardNumberQuery).number, 7);
    expect((WardQuery.parse('Nava-Vadaj') as WardTextQuery).text, 'navavadaj');
  });
}
