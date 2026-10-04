import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../shared/staff_api.dart';

/// Queue tab ids (`GET /staff/moderation?queue=`).
const staffQueues = ['sensitive', 'flagged', 'out_of_area'];

class StaffWardRef {
  const StaffWardRef({required this.id, required this.number, required this.nameEn, required this.nameGu});

  static StaffWardRef? fromJson(Object? j) {
    if (j is! Map) return null;
    return StaffWardRef(
      id: '${j['id']}',
      number: (j['number'] as num?)?.toInt() ?? 0,
      nameEn: '${j['nameEn'] ?? ''}',
      nameGu: '${j['nameGu'] ?? ''}',
    );
  }

  final String id;
  final int number;
  final String nameEn, nameGu;

  String name(String lang) => lang == 'gu' ? nameGu : nameEn;
}

class FlagCount {
  const FlagCount(this.reason, this.count);
  final String reason;
  final int count;

  static List<FlagCount> list(Object? j) => [
    for (final f in (j as List? ?? const []))
      FlagCount('${(f as Map)['reason']}', (f['count'] as num).toInt()),
  ];
}

class QueueItem {
  const QueueItem({
    required this.id,
    required this.title,
    required this.status,
    required this.categorySlug,
    required this.createdAt,
    required this.ward,
    required this.openFlags,
    required this.thumbUrl,
  });

  factory QueueItem.fromJson(Json j) => QueueItem(
    id: '${j['id']}',
    title: '${j['title']}',
    status: '${j['status']}',
    categorySlug: '${(j['category'] as Map)['slug']}',
    createdAt: DateTime.parse('${j['createdAt']}'),
    ward: StaffWardRef.fromJson(j['ward']),
    openFlags: FlagCount.list(j['openFlags']),
    thumbUrl: j['photoThumbUrl'] as String?,
  );

  final String id, title, status, categorySlug;
  final DateTime createdAt;
  final StaffWardRef? ward;
  final List<FlagCount> openFlags;
  final String? thumbUrl;
}

class QueuePage {
  const QueuePage(this.items, this.nextCursor);
  final List<QueueItem> items;
  final String? nextCursor;
}

final staffQueueProvider = FutureProvider.autoDispose.family<QueuePage, String>((ref, queue) async {
  final j = await ref.watch(staffApiProvider).queue(queue);
  return QueuePage(
    [for (final i in (j['items'] as List)) QueueItem.fromJson((i as Map).cast<String, dynamic>())],
    j['nextCursor'] as String?,
  );
});

/// Dart status for an API status string (`merged` has no citizen style).
IssueStatus? issueStatusOf(String s) => switch (s) {
  'reported' => IssueStatus.reported,
  'sent' => IssueStatus.sent,
  'acknowledged' => IssueStatus.acknowledged,
  'in_progress' => IssueStatus.inProgress,
  'marked_fixed' => IssueStatus.markedFixed,
  'verified' => IssueStatus.verified,
  'reopened' => IssueStatus.reopened,
  'rejected' => IssueStatus.rejected,
  _ => null,
};
