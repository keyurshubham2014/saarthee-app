/// TASK-11 ward dashboard payloads (`GET /staff/ward-dashboard`, §5.3).
library;

typedef Json = Map<String, dynamic>;

int _i(Object? v) => (v as num?)?.toInt() ?? 0;

class ScopeWard {
  const ScopeWard({
    required this.id,
    required this.number,
    required this.nameEn,
    required this.nameGu,
  });

  factory ScopeWard.fromJson(Json j) => ScopeWard(
    id: '${j['id']}',
    number: _i(j['number']),
    nameEn: '${j['nameEn'] ?? ''}',
    nameGu: '${j['nameGu'] ?? ''}',
  );

  final String id;
  final int number;
  final String nameEn;
  final String nameGu;

  String name(String lang) => lang == 'gu' ? nameGu : nameEn;
}

class CategoryAge {
  const CategoryAge(
    this.slug,
    this.d0to7,
    this.d8to30,
    this.d31Plus,
    this.total,
  );

  factory CategoryAge.fromJson(Json j) => CategoryAge(
    '${j['slug']}',
    _i(j['d0_7']),
    _i(j['d8_30']),
    _i(j['d31Plus']),
    _i(j['total']),
  );

  final String slug;
  final int d0to7;
  final int d8to30;
  final int d31Plus;
  final int total;
}

class OverdueIssue {
  const OverdueIssue(
    this.issueId,
    this.title,
    this.category,
    this.status,
    this.ageDays,
  );

  factory OverdueIssue.fromJson(Json j) => OverdueIssue(
    '${j['issueId']}',
    '${j['title'] ?? ''}',
    '${j['category']}',
    '${j['status']}',
    _i(j['ageDays']),
  );

  final String issueId;
  final String title;
  final String category;
  final String status;
  final int ageDays;
}

class Hotspot {
  const Hotspot(this.lat, this.lng, this.count);

  factory Hotspot.fromJson(Json j) => Hotspot(
    (j['lat'] as num).toDouble(),
    (j['lng'] as num).toDouble(),
    _i(j['count']),
  );

  final double lat;
  final double lng;
  final int count;
}

class TrendWeek {
  const TrendWeek(
    this.weekStart,
    this.reported,
    this.markedFixed,
    this.verified,
  );

  factory TrendWeek.fromJson(Json j) => TrendWeek(
    '${j['weekStart']}',
    _i(j['reported']),
    _i(j['markedFixed']),
    _i(j['verified']),
  );

  final String weekStart;
  final int reported;
  final int markedFixed;
  final int verified;
}

class WardDashboard {
  const WardDashboard({
    required this.ward,
    required this.generatedAt,
    required this.open,
    required this.overdueCount,
    required this.markedFixed30d,
    required this.verified30d,
    required this.byCategory,
    required this.overdue,
    required this.hotspots,
    required this.trend,
    required this.electionActive,
  });

  factory WardDashboard.fromJson(Json j) {
    final t = j['totals'] as Json? ?? const {};
    List<T> list<T>(String k, T Function(Json) f) => [
      for (final x in (j[k] as List? ?? const [])) f(x as Json),
    ];
    return WardDashboard(
      ward: ScopeWard.fromJson(j['ward'] as Json),
      generatedAt: DateTime.tryParse('${j['generatedAt']}') ?? DateTime.now(),
      open: _i(t['open']),
      overdueCount: _i(t['overdue']),
      markedFixed30d: _i(t['markedFixed30d']),
      verified30d: _i(t['verified30d']),
      byCategory: list('byCategory', CategoryAge.fromJson),
      overdue: list('overdue', OverdueIssue.fromJson),
      hotspots: list('hotspots', Hotspot.fromJson),
      trend: list('trend', TrendWeek.fromJson),
      electionActive: (j['electionMode'] as Json?)?['active'] == true,
    );
  }

  final ScopeWard ward;
  final DateTime generatedAt;
  final int open;
  final int overdueCount;
  final int markedFixed30d;
  final int verified30d;
  final List<CategoryAge> byCategory;
  final List<OverdueIssue> overdue;
  final List<Hotspot> hotspots;
  final List<TrendWeek> trend;
  final bool electionActive;
}
