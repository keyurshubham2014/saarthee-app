import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/api/app_error.dart';
import 'package:saarthee/features/issue_actions/application/escalation.dart';
import 'package:saarthee/features/issue_actions/data/issue_actions_api.dart';
import 'package:saarthee/features/issue_actions/data/issue_models.dart';

const kIssueId = '11111111-2222-4333-8444-555555555555';

/// Issue at 23.0225, 72.5714 (FakeEvidenceCapture's default fix is on it).
IssueLifecycle sampleIssue({
  String status = 'marked_fixed',
  String? displayStatus,
  ViewerActions actions = const ViewerActions(verify: true),
  DateTime? closes,
  bool answeredToday = false,
  bool overdue = false,
  DateTime? ccrsDeadline,
  int version = 1,
}) => IssueLifecycle(
  id: kIssueId,
  status: issueStatusFromApi(status),
  apiStatus: status,
  displayStatus: displayStatus ?? status,
  statusVersion: version,
  latitude: 23.0225,
  longitude: 72.5714,
  isOverdue: overdue,
  verifyWindowClosesAt: closes ?? DateTime.now().add(const Duration(days: 6)),
  categoryNameEn: 'Roads & potholes',
  categoryNameGu: 'રસ્તા',
  wardNameEn: 'Paldi',
  wardNameGu: 'પાલડી',
  answeredToday: answeredToday,
  ccrsReopenDeadline: ccrsDeadline,
  actions: actions,
);

IssueEventItem ev(
  String id,
  String type, {
  String? to,
  String actor = 'resident',
  String? answer,
  String? level,
  List<String> photos = const [],
  String? note,
  String? nameEn,
  String? repRole,
  DateTime? at,
}) => IssueEventItem(
  id: id,
  type: type,
  toStatus: to,
  actorKind: actor,
  wardNameEn: 'Paldi',
  wardNameGu: 'પાલડી',
  actorNameEn: nameEn,
  actorNameGu: nameEn,
  repRole: repRole,
  answer: answer,
  level: level,
  note: note,
  photoUrls: photos,
  createdAt: at ?? DateTime.utc(2026, 10, 3, 6),
);

/// Records calls; [verifyGate] holds the verify response until completed.
class FakeIssueActionsApi implements IssueActionsApi {
  FakeIssueActionsApi({IssueLifecycle? issue, List<IssueEventItem>? events})
    : issue = issue ?? sampleIssue(),
      eventList = events ?? [ev('e1', 'status_change', to: 'reported')];

  IssueLifecycle issue;
  List<IssueEventItem> eventList;
  Completer<VerifyResult>? verifyGate;
  AppError? statusError;
  AppError? verifyError;
  EscalationDraft? draft;
  final List<Map<String, Object?>> verifyCalls = [];
  final List<Map<String, Object?>> statusCalls = [];
  final List<String> uploads = [];
  final List<String> escalations = [];
  int ccrsCalls = 0;

  @override
  Future<IssueLifecycle> lifecycle(String issueId) async => issue;

  @override
  Future<(List<IssueEventItem>, String?)> events(
    String issueId, {
    String? cursor,
  }) async => (List.of(eventList), null);

  @override
  Future<String> uploadPhoto(
    String issueId,
    String path,
    String purpose, {
    bool blurApplied = false,
  }) async {
    uploads.add(purpose);
    return 'photo-${uploads.length}';
  }

  @override
  Future<void> changeStatus(
    String issueId, {
    required String to,
    required String expectedStatus,
    required String clientActionId,
    String? note,
    List<String> photoIds = const [],
  }) async {
    statusCalls.add({
      'to': to,
      'expectedStatus': expectedStatus,
      'clientActionId': clientActionId,
      'note': note,
      'photoIds': photoIds,
    });
    if (statusError != null) throw statusError!;
  }

  @override
  Future<VerifyResult> verify(String issueId, Map<String, Object?> body) async {
    verifyCalls.add(body);
    if (verifyError != null) throw verifyError!;
    final gate = verifyGate;
    return gate == null
        ? const VerifyResult(status: 'verified', displayStatus: 'verified')
        : gate.future;
  }

  @override
  Future<EscalationDraft> escalate(
    String issueId,
    String level,
    String lang,
  ) async {
    escalations.add('$level/$lang');
    return draft ??
        EscalationDraft(
          level: level,
          recommendedLevel: 'corporators',
          subject: 'Overdue civic issue in ward Paldi — Roads',
          message: 'Dear Corporator, … https://saarthee.in/i/$issueId …',
          evidenceUrl: 'https://saarthee.in/i/$issueId',
          targets: const [],
          independenceNote: 'Saarthee prepares this message for you.',
        );
  }

  @override
  Future<DateTime?> ccrsClosed(String issueId) async {
    ccrsCalls++;
    return DateTime.now().add(const Duration(hours: 24));
  }
}

class FakeLauncher extends EscalationLauncher {
  final List<String> calls = [];
  @override
  Future<bool> email(String to, String subject, String body) async {
    calls.add('email:$to');
    return true;
  }

  @override
  Future<bool> call(String phone) async {
    calls.add('call:$phone');
    return true;
  }

  @override
  Future<void> share(String text) async => calls.add('share');
  @override
  Future<void> copy(String text) async => calls.add('copy');
  @override
  Future<bool> openUrl(String url) async {
    calls.add('open:$url');
    return true;
  }
}

/// Captures `SemanticsService` announcements for the rest of the test.
List<String> captureAnnouncements(WidgetTester t) {
  final announced = <String>[];
  t.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(
    SystemChannels.accessibility,
    (m) async {
      final data = (m as Map)['data'] as Map?;
      if (data?['message'] is String) announced.add(data!['message'] as String);
      return null;
    },
  );
  addTearDown(
    () =>
        t.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(
          SystemChannels.accessibility,
          null,
        ),
  );
  return announced;
}
