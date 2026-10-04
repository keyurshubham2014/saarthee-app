import 'package:flutter/foundation.dart';

import 'ward.dart';

/// Ward search (TASK-02 §5.3 `q`, §5.4) — the same rules as the API's
/// `apps/api/src/modules/geo/ward-search.ts`, checked by the shared table
/// `apps/api/test/fixtures/geo/ward-search-cases.json`:
/// - case-insensitive; spaces, hyphens and punctuation ignored;
/// - Gujarati digits ૦–૯ count as 0–9;
/// - leading "ward" / "વોર્ડ" / "no." / "નં." prefixes ignored;
/// - a query that is only digits matches the ward number exactly; anything
///   else is a substring match on the English (transliterated) or the
///   Gujarati name, whatever the app language.

sealed class WardQuery {
  const WardQuery();

  static WardQuery parse(String? raw) {
    var q = toAsciiDigits(raw ?? '').trim().toLowerCase();
    q = q.replaceFirst(_wardPrefix, '').replaceFirst(_noPrefix, '');
    final text = compact(q);
    if (text.isEmpty) return const AllWards();
    if (_digitsOnly.hasMatch(text)) return WardNumberQuery(int.parse(text));
    return WardTextQuery(text);
  }

  bool matches(Ward w);
}

class AllWards extends WardQuery {
  const AllWards();

  @override
  bool matches(Ward w) => true;
}

class WardNumberQuery extends WardQuery {
  const WardNumberQuery(this.number);

  final int number;

  @override
  bool matches(Ward w) => w.number == number;
}

class WardTextQuery extends WardQuery {
  const WardTextQuery(this.text);

  final String text;

  @override
  bool matches(Ward w) =>
      compact(w.nameEn).contains(text) || compact(w.nameGu).contains(text);
}

final _wardPrefix = RegExp(
  r'^(ward|વોર્ડ)\s*(no\.?|number|નં\.?|નંબર)?\s*',
  unicode: true,
);
final _noPrefix = RegExp(r'^(no\.?|નં\.?)\s*', unicode: true);
final _digitsOnly = RegExp(r'^\d+$');
final _notWordChar = RegExp(r'[^\p{L}\p{M}\p{N}]+', unicode: true);

/// Gujarati digit zero, ૦ (U+0AE6); ૧–૯ follow it.
const _guZero = 0x0AE6;

/// "૧૫" → "15"; other characters unchanged.
String toAsciiDigits(String s) => String.fromCharCodes([
  for (final r in s.runes)
    r >= _guZero && r <= _guZero + 9 ? 0x30 + r - _guZero : r,
]);

/// Lower-case with spaces and punctuation removed (keeps letters, Gujarati
/// combining marks and digits).
String compact(String s) => s.toLowerCase().replaceAll(_notWordChar, '');

/// One zone heading in the picker with its matching wards.
@immutable
class ZoneGroup {
  const ZoneGroup(this.zone, this.wards);

  final Zone zone;
  final List<Ward> wards;
}

/// Filters [wards] by [query] and groups them by zone: zones in the fixed
/// AMC order (Central, North, South, East, West, North West, South West;
/// unknown zones after, by English name), wards by number. Only groups
/// with at least one match are returned.
List<ZoneGroup> groupAndFilter(List<Ward> wards, String query) {
  final q = WardQuery.parse(query);
  final byZone = <String, List<Ward>>{};
  final zones = <String, Zone>{};
  for (final w in wards) {
    if (!q.matches(w)) continue;
    byZone.putIfAbsent(w.zone.id, () => []).add(w);
    zones[w.zone.id] = w.zone;
  }
  final ordered = zones.values.toList()
    ..sort((a, b) {
      final byIndex = a.sortIndex.compareTo(b.sortIndex);
      return byIndex != 0 ? byIndex : a.nameEn.compareTo(b.nameEn);
    });
  return [
    for (final z in ordered)
      ZoneGroup(z, byZone[z.id]!..sort((a, b) => a.number.compareTo(b.number))),
  ];
}
