import 'json_read.dart';

/// Derived complaint status from `complaint_status_v`.
enum ComplaintStatus {
  filed('filed'),
  reminded('reminded'),
  verifiedFixed('verified_fixed'),
  verifiedNotFixed('verified_not_fixed');

  const ComplaintStatus(this.wire);
  final String wire;

  static ComplaintStatus fromWire(String? value) => ComplaintStatus.values
      .firstWhere((s) => s.wire == value, orElse: () => ComplaintStatus.filed);
}

/// Admin list item (03 §2.3). Deliberately has no phone field.
class ComplaintSummary {
  const ComplaintSummary({
    required this.id,
    required this.createdAt,
    required this.sourceTag,
    required this.categoryName,
    required this.ccrsNumber,
    required this.groupLabel,
    required this.ccrsDuplicate,
    required this.status,
    required this.isDue,
    required this.reminderCount,
    required this.lastReminderAt,
    required this.verificationCount,
    required this.latestResult,
    required this.latestVerifiedAt,
    required this.isExcluded,
    required this.exclusionReason,
    required this.anonymized,
  });

  factory ComplaintSummary.fromJson(Map<String, dynamic> json) =>
      ComplaintSummary(
        id: readString(json, 'id'),
        createdAt: readDateOrNull(json, 'createdAt') ?? DateTime.now(),
        sourceTag: readString(json, 'sourceTag'),
        categoryName: readString(json, 'categoryName'),
        ccrsNumber: readString(json, 'ccrsNumber'),
        groupLabel: readStringOrNull(json, 'groupLabel'),
        ccrsDuplicate: readBool(json, 'ccrsDuplicate'),
        status: ComplaintStatus.fromWire(readStringOrNull(json, 'status')),
        isDue: readBool(json, 'isDue'),
        reminderCount: readInt(json, 'reminderCount'),
        lastReminderAt: readDateOrNull(json, 'lastReminderAt'),
        verificationCount: readInt(json, 'verificationCount'),
        latestResult: readStringOrNull(json, 'latestResult'),
        latestVerifiedAt: readDateOrNull(json, 'latestVerifiedAt'),
        isExcluded: readBool(json, 'isExcluded'),
        exclusionReason: readStringOrNull(json, 'exclusionReason'),
        anonymized: readBool(json, 'anonymized'),
      );

  final String id;
  final DateTime createdAt;
  final String sourceTag;
  final String categoryName;
  final String ccrsNumber;
  final String? groupLabel;
  final bool ccrsDuplicate;
  final ComplaintStatus status;
  final bool isDue;
  final int reminderCount;
  final DateTime? lastReminderAt;
  final int verificationCount;
  final String? latestResult;
  final DateTime? latestVerifiedAt;
  final bool isExcluded;
  final String? exclusionReason;
  final bool anonymized;
}

/// One page of `GET /admin/complaints`.
class ComplaintPage {
  const ComplaintPage({required this.items, required this.nextCursor});

  factory ComplaintPage.fromJson(Map<String, dynamic> json) => ComplaintPage(
    items: readList(
      json,
      'items',
    ).map(ComplaintSummary.fromJson).toList(growable: false),
    nextCursor: readStringOrNull(json, 'nextCursor'),
  );

  final List<ComplaintSummary> items;
  final String? nextCursor;
}

/// Filters for the complaint list (03 §2.2). Value-equal so it can key a
/// Riverpod family.
class ComplaintFilter {
  const ComplaintFilter({
    this.due,
    this.source,
    this.categoryId,
    this.status,
    this.excluded = ExcludedFilter.notExcluded,
    this.ccrsDuplicate,
  });

  static const dueOnly = ComplaintFilter(due: true);

  final bool? due;
  final String? source;
  final String? categoryId;
  final ComplaintStatus? status;
  final ExcludedFilter excluded;
  final bool? ccrsDuplicate;

  bool get hasActiveFilters =>
      source != null ||
      categoryId != null ||
      status != null ||
      excluded != ExcludedFilter.notExcluded ||
      ccrsDuplicate != null;

  ComplaintFilter copyWith({
    String? Function()? source,
    String? Function()? categoryId,
    ComplaintStatus? Function()? status,
    ExcludedFilter? excluded,
    bool? Function()? ccrsDuplicate,
  }) => ComplaintFilter(
    due: due,
    source: source != null ? source() : this.source,
    categoryId: categoryId != null ? categoryId() : this.categoryId,
    status: status != null ? status() : this.status,
    excluded: excluded ?? this.excluded,
    ccrsDuplicate: ccrsDuplicate != null ? ccrsDuplicate() : this.ccrsDuplicate,
  );

  Map<String, dynamic> toQuery() => <String, dynamic>{
    if (due != null) 'due': due.toString(),
    if (source != null) 'source': source,
    if (categoryId != null) 'categoryId': categoryId,
    if (status != null) 'status': status!.wire,
    'excluded': excluded.wire,
    if (ccrsDuplicate != null) 'ccrsDuplicate': ccrsDuplicate.toString(),
  };

  @override
  bool operator ==(Object other) =>
      other is ComplaintFilter &&
      other.due == due &&
      other.source == source &&
      other.categoryId == categoryId &&
      other.status == status &&
      other.excluded == excluded &&
      other.ccrsDuplicate == ccrsDuplicate;

  @override
  int get hashCode =>
      Object.hash(due, source, categoryId, status, excluded, ccrsDuplicate);
}

/// `excluded` query parameter.
enum ExcludedFilter {
  notExcluded('false'),
  onlyExcluded('true'),
  all('all');

  const ExcludedFilter(this.wire);
  final String wire;
}
