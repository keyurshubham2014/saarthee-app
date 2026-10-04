import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/api/api_client.dart';
import 'issue_models.dart';

/// Escalation response (TASK-06 §5.3).
class EscalationDraft {
  const EscalationDraft({
    required this.level,
    required this.recommendedLevel,
    required this.subject,
    required this.message,
    required this.evidenceUrl,
    required this.targets,
    required this.independenceNote,
  });

  factory EscalationDraft.fromJson(Map<String, dynamic> j) => EscalationDraft(
    level: j['level'] as String,
    recommendedLevel: j['recommendedLevel'] as String? ?? 'corporators',
    subject: j['subject'] as String? ?? '',
    message: j['message'] as String? ?? '',
    evidenceUrl: j['evidenceUrl'] as String? ?? '',
    independenceNote: j['independenceNote'] as String? ?? '',
    targets: [
      for (final t in (j['targets'] as List? ?? const []))
        EscalationTarget.fromJson(Map<String, dynamic>.from(t as Map)),
    ],
  );

  final String level, recommendedLevel, subject, message, evidenceUrl;
  final String independenceNote;
  final List<EscalationTarget> targets;
}

class EscalationTarget {
  const EscalationTarget({
    required this.kind,
    required this.label,
    this.representativeId,
    this.email,
    this.phone,
  });

  factory EscalationTarget.fromJson(Map<String, dynamic> j) => EscalationTarget(
    kind: j['kind'] as String? ?? 'relay',
    label: j['label'] as String? ?? '',
    representativeId: j['representativeId'] as String?,
    email: j['email'] as String?,
    phone: j['phone'] as String?,
  );

  final String kind, label;
  final String? representativeId, email, phone;
}

/// Result of `POST /issues/{id}/verifications`.
class VerifyResult {
  const VerifyResult({required this.status, required this.displayStatus});
  final String status, displayStatus;
}

/// Lifecycle endpoints (TASK-06). Screens use the providers, never Dio.
abstract interface class IssueActionsApi {
  Future<IssueLifecycle> lifecycle(String issueId);
  Future<(List<IssueEventItem>, String?)> events(
    String issueId, {
    String? cursor,
  });

  /// `POST /photos` with `purpose` after | verification.
  Future<String> uploadPhoto(String issueId, String path, String purpose);

  Future<void> changeStatus(
    String issueId, {
    required String to,
    required String expectedStatus,
    required String clientActionId,
    String? note,
    List<String> photoIds,
  });

  Future<VerifyResult> verify(String issueId, Map<String, Object?> body);
  Future<EscalationDraft> escalate(String issueId, String level, String lang);
  Future<DateTime?> ccrsClosed(String issueId);
}

class HttpIssueActionsApi implements IssueActionsApi {
  HttpIssueActionsApi(this._api);
  final ApiClient _api;

  @override
  Future<IssueLifecycle> lifecycle(String issueId) async =>
      IssueLifecycle.fromJson(await _api.getJson('/issues/$issueId/lifecycle'));

  @override
  Future<(List<IssueEventItem>, String?)> events(
    String issueId, {
    String? cursor,
  }) async {
    final res = await _api.getJson(
      '/issues/$issueId/events',
      query: {'limit': '50', 'cursor': ?cursor},
    );
    return (
      [
        for (final e in (res['items'] as List? ?? const []))
          IssueEventItem.fromJson(Map<String, dynamic>.from(e as Map)),
      ],
      res['nextCursor'] as String?,
    );
  }

  @override
  Future<String> uploadPhoto(
    String issueId,
    String path,
    String purpose,
  ) async {
    final res = await _api.uploadFile(
      '/photos',
      filePath: path,
      fields: {'purpose': purpose, 'issueId': issueId, 'blurApplied': 'false'},
    );
    return res['photoId'] as String;
  }

  @override
  Future<void> changeStatus(
    String issueId, {
    required String to,
    required String expectedStatus,
    required String clientActionId,
    String? note,
    List<String> photoIds = const [],
  }) => _api.postJson(
    '/issues/$issueId/status',
    body: {
      'to': to,
      'expectedStatus': expectedStatus,
      'clientActionId': clientActionId,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      if (photoIds.isNotEmpty) 'photoIds': photoIds,
    },
  );

  @override
  Future<VerifyResult> verify(String issueId, Map<String, Object?> body) async {
    final res = await _api.postJson(
      '/issues/$issueId/verifications',
      body: body,
    );
    final i = Map<String, dynamic>.from((res['issue'] as Map?) ?? const {});
    return VerifyResult(
      status: i['status'] as String? ?? '',
      displayStatus: i['displayStatus'] as String? ?? '',
    );
  }

  @override
  Future<EscalationDraft> escalate(
    String issueId,
    String level,
    String lang,
  ) async => EscalationDraft.fromJson(
    await _api.postJson(
      '/issues/$issueId/escalations',
      body: {'level': level, 'language': lang},
    ),
  );

  @override
  Future<DateTime?> ccrsClosed(String issueId) async {
    final res = await _api.postJson('/issues/$issueId/ccrs/closed', body: {});
    final d = res['reopenDeadline'];
    return d is String ? DateTime.tryParse(d) : null;
  }
}

final issueActionsApiProvider = Provider<IssueActionsApi>(
  (ref) => HttpIssueActionsApi(ref.watch(apiClientProvider)),
);

/// New idempotency key per user action (kept across retries of that action).
String newActionId() => const Uuid().v4();
