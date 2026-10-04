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
    final zone = j['zone'];
    return Ward(
      id: '${j['id'] ?? ''}',
      number: (j['number'] as num?)?.toInt() ?? 0,
      nameEn: '${j['nameEn'] ?? ''}',
      nameGu: '${j['nameGu'] ?? j['nameEn'] ?? ''}',
      zone: zone is Map<String, dynamic>
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

/// `GET /geo/locate` result; `confirm` means "just outside the boundary".
@immutable
class WardLocateResult {
  const WardLocateResult({required this.ward, required this.confirm});

  final Ward ward;
  final bool confirm;
}
