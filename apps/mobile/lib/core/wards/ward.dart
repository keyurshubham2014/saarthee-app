import 'package:flutter/foundation.dart';

/// A city zone (TASK-02 contract, TASK-03 §5.3).
@immutable
class Zone {
  const Zone({
    required this.id,
    required this.code,
    required this.nameEn,
    required this.nameGu,
  });

  final String id;
  final String code;
  final String nameEn;
  final String nameGu;

  String name(String languageCode) => languageCode == 'gu' ? nameGu : nameEn;

  /// Fixed display order of AMC's seven zones (TASK-02 §5.4).
  static const codeOrder = [
    'central',
    'north',
    'south',
    'east',
    'west',
    'north_west',
    'south_west',
  ];

  /// Position in [codeOrder]; unknown codes sort after the known ones.
  int get sortIndex {
    final i = codeOrder.indexOf(code);
    return i < 0 ? codeOrder.length : i;
  }

  factory Zone.fromJson(Map<String, dynamic> j) => Zone(
    id: '${j['id'] ?? ''}',
    code: '${j['code'] ?? ''}',
    nameEn: '${j['nameEn'] ?? ''}',
    nameGu: '${j['nameGu'] ?? j['nameEn'] ?? ''}',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'nameEn': nameEn,
    'nameGu': nameGu,
  };

  @override
  bool operator ==(Object other) => other is Zone && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// A municipal ward.
@immutable
class Ward {
  const Ward({
    required this.id,
    required this.number,
    required this.nameEn,
    required this.nameGu,
    required this.zone,
  });

  final String id;
  final int number;
  final String nameEn;
  final String nameGu;
  final Zone zone;

  String name(String languageCode) => languageCode == 'gu' ? nameGu : nameEn;

  /// "12 · Paldi" (picker rows).
  String shortLabel(String languageCode) => '$number · ${name(languageCode)}';

  factory Ward.fromJson(Map<String, dynamic> j) {
    final zone = j['zone'] is Map
        ? Map<String, dynamic>.from(j['zone'] as Map)
        : null;
    return Ward(
      id: '${j['id'] ?? ''}',
      number: (j['number'] as num?)?.toInt() ?? 0,
      nameEn: '${j['nameEn'] ?? ''}',
      nameGu: '${j['nameGu'] ?? j['nameEn'] ?? ''}',
      zone: zone != null
          ? Zone.fromJson(zone)
          : Zone(
              id: '${j['zoneId'] ?? ''}',
              code: '${j['zoneCode'] ?? ''}',
              nameEn: '${j['zoneNameEn'] ?? ''}',
              nameGu: '${j['zoneNameGu'] ?? j['zoneNameEn'] ?? ''}',
            ),
    );
  }

  /// Nested shape, as served by `GET /wards`.
  Map<String, dynamic> toJson() => {
    'id': id,
    'number': number,
    'nameEn': nameEn,
    'nameGu': nameGu,
    'zone': zone.toJson(),
  };

  /// Flat shape stored as `v2.homeWard` (TASK-03 §5.2).
  Map<String, dynamic> toPrefsJson() => {
    'id': id,
    'number': number,
    'nameEn': nameEn,
    'nameGu': nameGu,
    'zoneId': zone.id,
    'zoneCode': zone.code,
    'zoneNameEn': zone.nameEn,
    'zoneNameGu': zone.nameGu,
  };

  @override
  bool operator ==(Object other) => other is Ward && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// How `/geo/locate` assigned the ward (TASK-02 §5.3).
enum WardMatch {
  /// The point is inside the ward polygon.
  inside,

  /// Outside every ward but within `GEO_NEAREST_MAX_M` of this one; the
  /// user must confirm.
  nearest;

  static WardMatch parse(Object? v) =>
      v == 'nearest' ? WardMatch.nearest : WardMatch.inside;
}

/// `GET /geo/locate` result; `confirm` means "just outside the boundary".
@immutable
class WardLocateResult {
  const WardLocateResult({
    required this.ward,
    required this.confirm,
    this.match = WardMatch.inside,
    this.distanceM = 0,
    this.boundaryVersion,
  });

  /// Maps the 200 body `{ward, zone, match, confirm, distanceM,
  /// boundaryVersion}`; the ward's zone falls back to the top-level `zone`.
  factory WardLocateResult.fromJson(Map<String, dynamic> j) {
    final wardJson = Map<String, dynamic>.from(j['ward'] as Map);
    if (wardJson['zone'] is! Map && j['zone'] is Map) {
      wardJson['zone'] = j['zone'];
    }
    final match = WardMatch.parse(j['match']);
    return WardLocateResult(
      ward: Ward.fromJson(wardJson),
      match: match,
      confirm: j['confirm'] == true || match == WardMatch.nearest,
      distanceM: (j['distanceM'] as num?)?.round() ?? 0,
      boundaryVersion: j['boundaryVersion'] as String?,
    );
  }

  final Ward ward;
  final bool confirm;
  final WardMatch match;

  /// Metres outside the ward boundary (0 when [match] is inside).
  final int distanceM;
  final String? boundaryVersion;
}
