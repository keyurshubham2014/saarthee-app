import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../moderation/moderation_models.dart';
import '../shared/staff_api.dart';

class StaffFlag {
  const StaffFlag({required this.id, required this.targetType, required this.targetId, required this.reason, required this.note, required this.status});

  final String id, targetType, targetId, reason, status;
  final String? note;
}

class StaffEvent {
  const StaffEvent({
    required this.id,
    required this.type,
    required this.toStatus,
    required this.note,
    required this.createdAt,
    required this.hidden,
    required this.photoUrl,
  });

  final String id, type;
  final String? toStatus, note, photoUrl;
  final DateTime createdAt;
  final bool hidden;
}

class StaffPhoto {
  const StaffPhoto(this.id, this.kind, this.url);
  final String id, kind, url;
}

/// `GET /staff/issues/{id}` (never carries the reporter's name or phone).
class StaffIssue {
  const StaffIssue({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.hidden,
    required this.isSensitive,
    required this.moderated,
    required this.lat,
    required this.lng,
    required this.categoryId,
    required this.categorySlug,
    required this.categoryNameEn,
    required this.categoryNameGu,
    required this.ward,
    required this.reporterId,
    required this.photos,
    required this.openFlags,
    required this.flags,
    required this.timeline,
  });

  factory StaffIssue.fromJson(Json j) {
    final cat = (j['category'] as Map).cast<String, dynamic>();
    return StaffIssue(
      id: '${j['id']}',
      title: j['title'].toString(),
      description: j['description'] as String?,
      status: '${j['status']}',
      hidden: j['visibility'] == 'hidden',
      isSensitive: j['isSensitive'] == true,
      moderated: j['moderatedAt'] != null,
      lat: (j['lat'] as num).toDouble(),
      lng: (j['lng'] as num).toDouble(),
      categoryId: '${cat['id']}',
      categorySlug: '${cat['slug']}',
      categoryNameEn: '${cat['nameEn']}',
      categoryNameGu: '${cat['nameGu']}',
      ward: StaffWardRef.fromJson(j['ward']),
      reporterId: j['reporterId'] as String?,
      photos: [
        for (final p in (j['photos'] as List? ?? const []))
          StaffPhoto('${(p as Map)['id']}', '${p['kind']}', '${p['url']}'),
      ],
      openFlags: FlagCount.list(j['openFlags']),
      flags: [
        for (final f in (j['flags'] as List? ?? const []))
          StaffFlag(
            id: '${(f as Map)['id']}',
            targetType: '${f['targetType']}',
            targetId: '${f['targetId']}',
            reason: '${f['reason']}',
            note: f['note'] as String?,
            status: '${f['status']}',
          ),
      ],
      timeline: [
        for (final e in (j['timeline'] as List? ?? const []))
          StaffEvent(
            id: '${(e as Map)['id']}',
            type: '${e['type']}',
            toStatus: e['toStatus'] as String?,
            note: e['note'] as String?,
            createdAt: DateTime.parse('${e['createdAt']}'),
            hidden: e['hidden'] == true,
            photoUrl: e['photoUrl'] as String?,
          ),
      ],
    );
  }

  final String id, title, status, categoryId, categorySlug, categoryNameEn, categoryNameGu;
  final String? description, reporterId;
  final bool hidden, isSensitive, moderated;
  final double lat, lng;
  final StaffWardRef? ward;
  final List<StaffPhoto> photos;
  final List<FlagCount> openFlags;
  final List<StaffFlag> flags;
  final List<StaffEvent> timeline;

  bool get closed => status == 'rejected' || status == 'merged' || status == 'verified';
  bool get canAcknowledge => const ['reported', 'sent', 'reopened'].contains(status);
  bool get canStart => const ['reported', 'sent', 'acknowledged', 'reopened'].contains(status);
  bool get canMarkFixed => const ['reported', 'sent', 'acknowledged', 'in_progress', 'reopened'].contains(status);
}

final staffIssueProvider = FutureProvider.autoDispose.family<StaffIssue, String>(
  (ref, id) async => StaffIssue.fromJson(await ref.watch(staffApiProvider).issue(id)),
);

class MergeCandidate {
  const MergeCandidate({required this.id, required this.title, required this.distanceM, required this.far, required this.categorySlug});

  final String id, title, categorySlug;
  final int distanceM;
  final bool far;
}

final mergeCandidatesProvider = FutureProvider.autoDispose.family<List<MergeCandidate>, String>((ref, id) async {
  final j = await ref.watch(staffApiProvider).mergeCandidates(id);
  return [
    for (final c in (j['items'] as List))
      MergeCandidate(
        id: '${(c as Map)['id']}',
        title: c['title'].toString(),
        distanceM: (c['distanceM'] as num).toInt(),
        far: c['farWarning'] == true,
        categorySlug: '${(c['category'] as Map)['slug']}',
      ),
  ];
});
