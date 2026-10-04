/// Report flow data (TASK-05 §5.3): categories with AMC problem types,
/// duplicate suggestions and the submit result.
library;

class AmcProblemType {
  const AmcProblemType({
    required this.id,
    required this.deptEn,
    required this.deptGu,
    required this.problemEn,
    required this.problemGu,
    required this.isPrimary,
  });

  factory AmcProblemType.fromJson(Map<String, dynamic> j) => AmcProblemType(
    id: j['id'] as String,
    deptEn: j['deptEn'] as String? ?? '',
    deptGu: j['deptGu'] as String? ?? '',
    problemEn: j['problemEn'] as String? ?? '',
    problemGu: j['problemGu'] as String? ?? '',
    isPrimary: j['isPrimary'] == true,
  );

  final String id;
  final String deptEn;
  final String deptGu;
  final String problemEn;
  final String problemGu;
  final bool isPrimary;

  String dept(String lang) => lang == 'gu' ? deptGu : deptEn;
  String problem(String lang) => lang == 'gu' ? problemGu : problemEn;

  Map<String, Object?> toJson() => {
    'id': id,
    'deptEn': deptEn,
    'deptGu': deptGu,
    'problemEn': problemEn,
    'problemGu': problemGu,
    'isPrimary': isPrimary,
  };
}

class ReportCategory {
  const ReportCategory({
    required this.id,
    required this.slug,
    required this.nameEn,
    required this.nameGu,
    required this.slaDays,
    required this.sensitive,
    this.amcProblemTypes = const [],
  });

  factory ReportCategory.fromJson(Map<String, dynamic> j) => ReportCategory(
    id: j['id'] as String,
    slug: j['slug'] as String,
    nameEn: j['nameEn'] as String? ?? '',
    nameGu: j['nameGu'] as String? ?? '',
    slaDays: (j['slaDays'] as num?)?.toInt() ?? 7,
    sensitive: j['sensitive'] == true,
    amcProblemTypes: [
      for (final p in (j['amcProblemTypes'] as List? ?? const []))
        AmcProblemType.fromJson(Map<String, dynamic>.from(p as Map)),
    ],
  );

  final String id;
  final String slug;
  final String nameEn;
  final String nameGu;
  final int slaDays;
  final bool sensitive;
  final List<AmcProblemType> amcProblemTypes;

  AmcProblemType? get primaryAmc {
    for (final p in amcProblemTypes) {
      if (p.isPrimary) return p;
    }
    return null;
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'slug': slug,
    'nameEn': nameEn,
    'nameGu': nameGu,
    'slaDays': slaDays,
    'sensitive': sensitive,
    'amcProblemTypes': [for (final p in amcProblemTypes) p.toJson()],
  };
}

/// Structured reasons for the sensitive categories (§5.4), by API code.
const Map<String, List<String>> kStructuredReasons = {
  'encroachment': ['footpath', 'road', 'hawkers', 'other_obstruction'],
  'building': ['no_permission', 'unsafe', 'debris', 'other'],
};

class NearbyIssue {
  const NearbyIssue({
    required this.id,
    required this.categorySlug,
    required this.status,
    required this.distanceM,
    required this.meTooCount,
    required this.createdAt,
    this.wardNameEn,
    this.wardNameGu,
    this.thumbnailUrl,
  });

  factory NearbyIssue.fromJson(Map<String, dynamic> j) => NearbyIssue(
    id: j['id'] as String,
    categorySlug: j['categorySlug'] as String? ?? 'other',
    status: j['status'] as String? ?? 'reported',
    distanceM: (j['distanceM'] as num?)?.round() ?? 0,
    meTooCount: (j['meTooCount'] as num?)?.toInt() ?? 0,
    createdAt:
        DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime(2026),
    wardNameEn: j['wardNameEn'] as String?,
    wardNameGu: j['wardNameGu'] as String?,
    thumbnailUrl: j['thumbnailUrl'] as String?,
  );

  final String id;
  final String categorySlug;
  final String status;
  final int distanceM;
  final int meTooCount;
  final DateTime createdAt;
  final String? wardNameEn;
  final String? wardNameGu;
  final String? thumbnailUrl;
}

/// `POST /issues` 201/200 body.
class SubmittedIssue {
  const SubmittedIssue({
    required this.id,
    required this.status,
    required this.visibility,
    required this.categorySlug,
    required this.lat,
    required this.lng,
    this.wardNameEn,
    this.wardNameGu,
    this.problemTypes = const [],
  });

  factory SubmittedIssue.fromJson(
    Map<String, dynamic> j, {
    required String categorySlug,
    required double lat,
    required double lng,
  }) {
    final issue = Map<String, dynamic>.from(j['issue'] as Map);
    final handoff = j['amcHandoff'] is Map ? j['amcHandoff'] as Map : const {};
    return SubmittedIssue(
      id: issue['id'] as String,
      status: issue['status'] as String? ?? 'reported',
      visibility: issue['visibility'] as String? ?? 'public',
      wardNameEn: issue['wardNameEn'] as String?,
      wardNameGu: issue['wardNameGu'] as String?,
      categorySlug: categorySlug,
      lat: lat,
      lng: lng,
      problemTypes: [
        for (final p in (handoff['problemTypes'] as List? ?? const []))
          AmcProblemType.fromJson(Map<String, dynamic>.from(p as Map)),
      ],
    );
  }

  final String id;
  final String status;
  final String visibility;
  final String categorySlug;
  final double lat;
  final double lng;
  final String? wardNameEn;
  final String? wardNameGu;
  final List<AmcProblemType> problemTypes;

  bool get hidden => visibility == 'hidden';

  AmcProblemType? get primaryAmc {
    for (final p in problemTypes) {
      if (p.isPrimary) return p;
    }
    return problemTypes.isEmpty ? null : problemTypes.first;
  }
}
