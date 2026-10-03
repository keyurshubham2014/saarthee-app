import 'json_read.dart';

/// Invite code with its complaint count (TASK-09 §5.3).
class InviteCode {
  const InviteCode({
    required this.id,
    required this.code,
    required this.sourceTag,
    required this.groupLabel,
    required this.wardHint,
    required this.isActive,
    required this.complaintCount,
  });

  factory InviteCode.fromJson(Map<String, dynamic> json) => InviteCode(
    id: readString(json, 'id'),
    code: readString(json, 'code'),
    sourceTag: readString(json, 'sourceTag'),
    groupLabel: readString(json, 'groupLabel'),
    wardHint: readStringOrNull(json, 'wardHint'),
    isActive: readBool(json, 'isActive'),
    complaintCount: readInt(json, 'complaintCount'),
  );

  final String id;
  final String code;
  final String sourceTag;
  final String groupLabel;
  final String? wardHint;
  final bool isActive;
  final int complaintCount;
}

/// Complaint category (TASK-09 §5.3).
class AdminCategory {
  const AdminCategory({
    required this.id,
    required this.name,
    required this.ccrsLabel,
    required this.sortOrder,
    required this.isActive,
  });

  factory AdminCategory.fromJson(Map<String, dynamic> json) => AdminCategory(
    id: readString(json, 'id'),
    name: readString(json, 'name'),
    ccrsLabel: readStringOrNull(json, 'ccrsLabel'),
    sortOrder: readInt(json, 'sortOrder'),
    isActive: readBool(json, 'isActive'),
  );

  final String id;
  final String name;
  final String? ccrsLabel;
  final int sortOrder;
  final bool isActive;
}

/// Source tags an operator may assign to a new invite code.
const List<String> assignableSourceTags = <String>[
  'rwa',
  'activist',
  'social',
  'network',
];

/// All source tags that can appear on complaints (filters).
const List<String> allSourceTags = <String>[
  'rwa',
  'activist',
  'social',
  'network',
  'unknown',
];
