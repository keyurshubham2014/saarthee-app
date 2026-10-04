import 'package:flutter/foundation.dart';

/// Representative summary (TASK-09 §5.3 `RepSummary`). Never carries a
/// personal number, user id or consent data.
@immutable
class RepSummary {
  const RepSummary({
    required this.id,
    required this.nameEn,
    required this.nameGu,
    required this.role,
    required this.initials,
    required this.canMessage,
    required this.verified,
    this.partyText,
    this.wardNumber,
    this.areaEn,
    this.areaGu,
  });

  final String id;
  final String nameEn;
  final String nameGu;

  /// `corporator`, `mla` or `mp`.
  final String role;
  final String? partyText;
  final int? wardNumber;

  /// AC name (MLA) or Lok Sabha seat (MP).
  final String? areaEn;
  final String? areaGu;
  final String initials;
  final bool canMessage;
  final bool verified;

  String name(String lang) => lang == 'gu' ? nameGu : nameEn;
  String otherName(String lang) => lang == 'gu' ? nameEn : nameGu;
  String? area(String lang) => lang == 'gu' ? areaGu : areaEn;

  factory RepSummary.fromJson(Map<String, dynamic> j) => RepSummary(
    id: j['id'] as String,
    nameEn: j['nameEn'] as String,
    nameGu: j['nameGu'] as String,
    role: j['role'] as String,
    partyText: j['partyText'] as String?,
    wardNumber: (j['wardNumber'] as num?)?.toInt(),
    areaEn: j['acNameEn'] as String?,
    areaGu: j['acNameGu'] as String?,
    initials: j['initials'] as String,
    canMessage: j['canMessage'] as bool? ?? false,
    verified: j['verified'] as bool? ?? false,
  );
}

@immutable
class ElectionStatus {
  const ElectionStatus({
    required this.active,
    this.until,
    this.noteEn,
    this.noteGu,
  });

  static const ElectionStatus off = ElectionStatus(active: false);

  final bool active;
  final DateTime? until;
  final String? noteEn;
  final String? noteGu;

  factory ElectionStatus.fromJson(Map<String, dynamic>? j) {
    if (j == null) return off;
    final until = j['until'] as String?;
    return ElectionStatus(
      active: j['active'] as bool? ?? false,
      until: until == null ? null : DateTime.tryParse(until),
      noteEn: j['noteEn'] as String?,
      noteGu: j['noteGu'] as String?,
    );
  }
}

@immutable
class WardInfo {
  const WardInfo({
    required this.id,
    required this.number,
    required this.nameEn,
    required this.nameGu,
    required this.acCount,
    this.zoneEn,
    this.zoneGu,
    this.officeAddressEn,
    this.officeAddressGu,
    this.officePhone,
  });

  final String id;
  final int number;
  final String nameEn;
  final String nameGu;
  final String? zoneEn;
  final String? zoneGu;
  final String? officeAddressEn;
  final String? officeAddressGu;
  final String? officePhone;
  final int acCount;

  String name(String lang) => lang == 'gu' ? nameGu : nameEn;
  String? officeAddress(String lang) =>
      lang == 'gu' ? (officeAddressGu ?? officeAddressEn) : officeAddressEn;

  factory WardInfo.fromJson(Map<String, dynamic> j) {
    final zone = j['zone'] as Map<String, dynamic>?;
    return WardInfo(
      id: j['id'] as String,
      number: (j['number'] as num).toInt(),
      nameEn: j['nameEn'] as String,
      nameGu: j['nameGu'] as String,
      zoneEn: zone?['nameEn'] as String?,
      zoneGu: zone?['nameGu'] as String?,
      officeAddressEn: j['officeAddressEn'] as String?,
      officeAddressGu: j['officeAddressGu'] as String?,
      officePhone: j['officePhone'] as String?,
      acCount: (j['assemblyConstituencyCount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// `GET /wards/{id}/representatives`.
@immutable
class WardRepresentatives {
  const WardRepresentatives({
    required this.ward,
    required this.corporators,
    required this.mlas,
    required this.mps,
    required this.election,
    this.fromCache = false,
  });

  final WardInfo ward;
  final List<RepSummary> corporators;
  final List<RepSummary> mlas;
  final List<RepSummary> mps;
  final ElectionStatus election;

  /// Shown from the session cache because the device is offline.
  final bool fromCache;

  bool get isEmpty => corporators.isEmpty && mlas.isEmpty && mps.isEmpty;

  WardRepresentatives asCached() => WardRepresentatives(
    ward: ward,
    corporators: corporators,
    mlas: mlas,
    mps: mps,
    election: election,
    fromCache: true,
  );

  factory WardRepresentatives.fromJson(Map<String, dynamic> j) {
    List<RepSummary> list(String k) => [
      for (final r in (j[k] as List? ?? const []))
        RepSummary.fromJson(r as Map<String, dynamic>),
    ];
    return WardRepresentatives(
      ward: WardInfo.fromJson(j['ward'] as Map<String, dynamic>),
      corporators: list('corporators'),
      mlas: list('mlas'),
      mps: list('mps'),
      election: ElectionStatus.fromJson(
        j['electionMode'] as Map<String, dynamic>?,
      ),
    );
  }
}

/// `GET /representatives/{id}`.
@immutable
class RepDetail {
  const RepDetail({
    required this.summary,
    required this.sourceUrl,
    required this.lastVerifiedAt,
    required this.election,
    this.termStart,
    this.termEnd,
    this.officePhone,
    this.wardNameEn,
    this.wardNameGu,
    this.verificationJson,
  });

  final RepSummary summary;

  /// TASK-11 public verification block (parsed by the rep_claim feature).
  final Map<String, dynamic>? verificationJson;
  final DateTime? termStart;
  final DateTime? termEnd;
  final String? officePhone;
  final String sourceUrl;
  final DateTime? lastVerifiedAt;
  final String? wardNameEn;
  final String? wardNameGu;
  final ElectionStatus election;

  String? wardName(String lang) => lang == 'gu' ? wardNameGu : wardNameEn;

  String get sourceDomain => Uri.tryParse(sourceUrl)?.host ?? sourceUrl;

  factory RepDetail.fromJson(Map<String, dynamic> j) {
    DateTime? date(String k) =>
        j[k] == null ? null : DateTime.tryParse(j[k] as String);
    final ward = (j['areas'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .where((a) => a['kind'] == 'ward')
        .firstOrNull;
    return RepDetail(
      summary: RepSummary.fromJson(j),
      termStart: date('termStart'),
      termEnd: date('termEnd'),
      officePhone: j['officePhone'] as String?,
      sourceUrl: j['sourceUrl'] as String? ?? '',
      lastVerifiedAt: date('lastVerifiedAt'),
      wardNameEn: ward?['nameEn'] as String?,
      wardNameGu: ward?['nameGu'] as String?,
      verificationJson: j['verification'] as Map<String, dynamic>?,
      election: ElectionStatus.fromJson(
        j['electionMode'] as Map<String, dynamic>?,
      ),
    );
  }
}
