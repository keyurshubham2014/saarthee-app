import '../../../core/theme/tokens.dart';

/// Server status name → app enum (`merged` is shown as closed, like rejected).
IssueStatus issueStatusFromApi(String? s) => switch (s) {
  'sent' => IssueStatus.sent,
  'acknowledged' => IssueStatus.acknowledged,
  'in_progress' => IssueStatus.inProgress,
  'marked_fixed' => IssueStatus.markedFixed,
  'verified' => IssueStatus.verified,
  'reopened' => IssueStatus.reopened,
  'rejected' || 'merged' => IssueStatus.rejected,
  _ => IssueStatus.reported,
};

String issueStatusToApi(IssueStatus s) => switch (s) {
  IssueStatus.inProgress => 'in_progress',
  IssueStatus.markedFixed => 'marked_fixed',
  _ => s.name,
};

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;

/// What the viewer may do (from `GET /issues/{id}/lifecycle`).
class ViewerActions {
  const ViewerActions({
    this.acknowledge = false,
    this.start = false,
    this.markFixed = false,
    this.reject = false,
    this.verify = false,
    this.escalate = false,
    this.ccrsClosed = false,
  });

  factory ViewerActions.fromJson(Map<String, dynamic> j) => ViewerActions(
    acknowledge: j['acknowledge'] == true,
    start: j['start'] == true,
    markFixed: j['markFixed'] == true,
    reject: j['reject'] == true,
    verify: j['verify'] == true,
    escalate: j['escalate'] == true,
    ccrsClosed: j['ccrsClosed'] == true,
  );

  final bool acknowledge, start, markFixed, reject, verify, escalate;
  final bool ccrsClosed;
}

/// Lifecycle view of one issue.
class IssueLifecycle {
  const IssueLifecycle({
    required this.id,
    required this.status,
    required this.apiStatus,
    required this.displayStatus,
    required this.latitude,
    required this.longitude,
    this.statusVersion = 0,
    this.isOverdue = false,
    this.verifyWindowClosesAt,
    this.categoryNameEn = '',
    this.categoryNameGu = '',
    this.wardNameEn,
    this.wardNameGu,
    this.reportPhotoUrl,
    this.afterPhotoUrl,
    this.ccrsLinked = false,
    this.ccrsReopenDeadline,
    this.verifyRadiusM = 100,
    this.verifyMaxAccuracyM = 50,
    this.answeredToday = false,
    this.actions = const ViewerActions(),
  });

  factory IssueLifecycle.fromJson(Map<String, dynamic> j) {
    final i = Map<String, dynamic>.from(j['issue'] as Map);
    final v = Map<String, dynamic>.from((j['viewer'] as Map?) ?? const {});
    return IssueLifecycle(
      id: i['id'] as String,
      status: issueStatusFromApi(i['status'] as String?),
      apiStatus: i['status'] as String? ?? 'reported',
      displayStatus: i['displayStatus'] as String? ?? 'reported',
      statusVersion: (i['statusVersion'] as num?)?.toInt() ?? 0,
      latitude: (i['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (i['longitude'] as num?)?.toDouble() ?? 0,
      isOverdue: i['isOverdue'] == true,
      verifyWindowClosesAt: _date(i['verifyWindowClosesAt']),
      categoryNameEn: i['categoryNameEn'] as String? ?? '',
      categoryNameGu: i['categoryNameGu'] as String? ?? '',
      wardNameEn: i['wardNameEn'] as String?,
      wardNameGu: i['wardNameGu'] as String?,
      reportPhotoUrl: i['reportPhotoUrl'] as String?,
      afterPhotoUrl: i['afterPhotoUrl'] as String?,
      ccrsLinked: i['ccrsLinked'] == true,
      ccrsReopenDeadline: _date(i['ccrsReopenDeadline']),
      verifyRadiusM: (i['verifyRadiusM'] as num?)?.toInt() ?? 100,
      verifyMaxAccuracyM: (i['verifyMaxAccuracyM'] as num?)?.toInt() ?? 50,
      answeredToday: v['answeredToday'] == true,
      actions: ViewerActions.fromJson(
        Map<String, dynamic>.from((v['can'] as Map?) ?? const {}),
      ),
    );
  }

  final String id;
  final IssueStatus status;

  /// Exact server status (`expectedStatus` for status changes).
  final String apiStatus;

  /// `fixed_unverified` after the reopen window, else the status.
  final String displayStatus;
  final int statusVersion;
  final double latitude, longitude;
  final bool isOverdue;
  final DateTime? verifyWindowClosesAt;
  final String categoryNameEn, categoryNameGu;
  final String? wardNameEn, wardNameGu;
  final String? reportPhotoUrl, afterPhotoUrl;
  final bool ccrsLinked;
  final DateTime? ccrsReopenDeadline;
  final int verifyRadiusM, verifyMaxAccuracyM;
  final bool answeredToday;
  final ViewerActions actions;

  bool get fixedUnverified => displayStatus == 'fixed_unverified';
}

/// One `GET /issues/{id}/events` item.
class IssueEventItem {
  const IssueEventItem({
    required this.id,
    required this.type,
    this.toStatus,
    this.actorKind = 'system',
    this.wardNameEn,
    this.wardNameGu,
    this.actorNameEn,
    this.actorNameGu,
    this.repRole,
    this.note,
    this.photoUrls = const [],
    this.answer,
    this.createdAt,
  });

  factory IssueEventItem.fromJson(Map<String, dynamic> j) {
    final a = Map<String, dynamic>.from((j['actorLabel'] as Map?) ?? const {});
    final name = a['name'] is Map
        ? Map<String, dynamic>.from(a['name'] as Map)
        : null;
    final meta = Map<String, dynamic>.from((j['meta'] as Map?) ?? const {});
    return IssueEventItem(
      id: j['id'] as String,
      type: j['type'] as String? ?? 'status_change',
      toStatus: j['toStatus'] as String?,
      actorKind: a['kind'] as String? ?? 'system',
      wardNameEn: a['wardNameEn'] as String?,
      wardNameGu: a['wardNameGu'] as String?,
      actorNameEn: name?['en'] as String?,
      actorNameGu: name?['gu'] as String?,
      repRole: a['repRole'] as String?,
      note: j['note'] as String?,
      photoUrls: [for (final p in (j['photoUrls'] as List? ?? const [])) '$p'],
      answer: meta['answer'] as String?,
      createdAt: _date(j['createdAt']),
    );
  }

  final String id, type, actorKind;
  final String? toStatus, wardNameEn, wardNameGu, actorNameEn, actorNameGu;
  final String? repRole, note, answer;
  final List<String> photoUrls;
  final DateTime? createdAt;
}
