import '../../../core/theme/tokens.dart';

/// The eight alert types (API `alert_type`).
enum AlertType {
  waterCut('water_cut'),
  waterTiming('water_timing'),
  roadClosure('road_closure'),
  heat('heat'),
  rainFlood('rain_flood'),
  health('health'),
  initiative('initiative'),
  other('other');

  const AlertType(this.api);
  final String api;

  static AlertType parse(Object? v) =>
      values.firstWhere((t) => t.api == v, orElse: () => AlertType.other);
}

AlertSeverity parseSeverity(Object? v) => AlertSeverity.values.firstWhere(
  (s) => s.name == v,
  orElse: () => AlertSeverity.info,
);

enum AlertStatus { published, expired, retracted }

class AlertWardRef {
  const AlertWardRef({
    required this.id,
    required this.number,
    required this.nameEn,
    required this.nameGu,
  });

  final String id;
  final int number;
  final String nameEn;
  final String nameGu;

  factory AlertWardRef.fromJson(Map<String, dynamic> j) => AlertWardRef(
    id: j['id'] as String,
    number: (j['number'] as num).toInt(),
    nameEn: j['nameEn'] as String? ?? '',
    nameGu: j['nameGu'] as String? ?? '',
  );
}

/// Public alert (API `AlertDto`, detail adds wards and zone names).
class Alert {
  const Alert({
    required this.id,
    required this.type,
    required this.severity,
    required this.titleEn,
    required this.titleGu,
    required this.bodyEn,
    required this.bodyGu,
    required this.sourceName,
    required this.sourceUrl,
    required this.validFrom,
    required this.validTo,
    required this.scope,
    required this.wardNumbers,
    required this.status,
    this.zoneCode,
    this.zoneNameEn,
    this.zoneNameGu,
    this.wards = const [],
    this.retractionReason,
    this.supersededById,
  });

  final String id;
  final AlertType type;
  final AlertSeverity severity;
  final String titleEn, titleGu, bodyEn, bodyGu;
  final String sourceName, sourceUrl;
  final DateTime validFrom, validTo;

  /// `wards`, `zone` or `city`.
  final String scope;
  final List<int> wardNumbers;
  final String? zoneCode, zoneNameEn, zoneNameGu;
  final List<AlertWardRef> wards;
  final AlertStatus status;
  final String? retractionReason;
  final String? supersededById;

  bool get isActive => status == AlertStatus.published;

  String title(String lang) =>
      lang == 'gu' && titleGu.isNotEmpty ? titleGu : titleEn;
  String body(String lang) =>
      lang == 'gu' && bodyGu.isNotEmpty ? bodyGu : bodyEn;

  factory Alert.fromJson(Map<String, dynamic> j) {
    final target = (j['target'] as Map?)?.cast<String, dynamic>() ?? const {};
    final zone = (j['zone'] as Map?)?.cast<String, dynamic>();
    return Alert(
      id: j['id'] as String,
      type: AlertType.parse(j['type']),
      severity: parseSeverity(j['severity']),
      titleEn: j['titleEn'] as String? ?? '',
      titleGu: j['titleGu'] as String? ?? '',
      bodyEn: j['bodyEn'] as String? ?? '',
      bodyGu: j['bodyGu'] as String? ?? '',
      sourceName: j['sourceName'] as String? ?? '',
      sourceUrl: j['sourceUrl'] as String? ?? '',
      validFrom: DateTime.parse(j['validFrom'] as String),
      validTo: DateTime.parse(j['validTo'] as String),
      scope: target['scope'] as String? ?? 'city',
      wardNumbers: [
        for (final n in (target['wardNumbers'] as List? ?? const []))
          (n as num).toInt(),
      ],
      zoneCode: target['zoneCode'] as String?,
      zoneNameEn: zone?['nameEn'] as String?,
      zoneNameGu: zone?['nameGu'] as String?,
      wards: [
        for (final w in (j['wards'] as List? ?? const []))
          AlertWardRef.fromJson((w as Map).cast<String, dynamic>()),
      ],
      status: AlertStatus.values.firstWhere(
        (s) => s.name == j['status'],
        orElse: () => AlertStatus.expired,
      ),
      retractionReason: j['retractionReason'] as String?,
      supersededById: j['supersededById'] as String?,
    );
  }
}

/// `GET/PUT /me/subscriptions` and `/devices/{installId}/subscriptions`.
class AlertSubscriptions {
  const AlertSubscriptions({
    this.homeWardId,
    this.extraWardIds = const [],
    this.mutedTypes = const {},
    this.criticalOnly = false,
    this.topics = const [],
  });

  final String? homeWardId;
  final List<String> extraWardIds;
  final Set<AlertType> mutedTypes;
  final bool criticalOnly;

  /// Base topics (no language suffix) the phone should hold; empty = custom.
  final List<String> topics;

  bool get customPreferences => mutedTypes.isNotEmpty || criticalOnly;

  AlertSubscriptions copyWith({
    List<String>? extraWardIds,
    Set<AlertType>? mutedTypes,
    bool? criticalOnly,
  }) => AlertSubscriptions(
    homeWardId: homeWardId,
    extraWardIds: extraWardIds ?? this.extraWardIds,
    mutedTypes: mutedTypes ?? this.mutedTypes,
    criticalOnly: criticalOnly ?? this.criticalOnly,
    topics: topics,
  );

  Map<String, dynamic> toJson() => {
    'extraWardIds': extraWardIds,
    'mutedTypes': [for (final t in mutedTypes) t.api],
    'criticalOnly': criticalOnly,
  };

  factory AlertSubscriptions.fromJson(Map<String, dynamic> j) =>
      AlertSubscriptions(
        homeWardId: j['homeWardId'] as String?,
        extraWardIds: [
          for (final w in (j['extraWardIds'] as List? ?? const [])) w as String,
        ],
        mutedTypes: {
          for (final t in (j['mutedTypes'] as List? ?? const []))
            AlertType.parse(t),
        },
        criticalOnly: j['criticalOnly'] as bool? ?? false,
        topics: [
          for (final t in (j['topics'] as List? ?? const [])) t as String,
        ],
      );
}
