import 'complaint_summary.dart';
import 'json_read.dart';

/// A reminder in the complaint detail timeline. Never includes the token.
class ReminderEntry {
  const ReminderEntry({
    required this.id,
    required this.sentAt,
    required this.sentBy,
    required this.channel,
    required this.revokedAt,
  });

  factory ReminderEntry.fromJson(Map<String, dynamic> json) => ReminderEntry(
    id: readString(json, 'id'),
    sentAt: readDateOrNull(json, 'sentAt') ?? DateTime.now(),
    sentBy: readStringOrNull(json, 'sentBy'),
    channel: readString(json, 'channel'),
    revokedAt: readDateOrNull(json, 'revokedAt'),
  );

  final String id;
  final DateTime sentAt;
  final String? sentBy;
  final String channel;
  final DateTime? revokedAt;

  bool get isActive => revokedAt == null;
}

/// A citizen verification of a complaint.
class VerificationEntry {
  const VerificationEntry({
    required this.id,
    required this.result,
    required this.createdAt,
    required this.deviceCapturedAt,
    required this.distanceFromReportM,
    required this.distanceWarning,
    required this.sameImageAsReport,
    required this.note,
    required this.hasPhoto,
  });

  factory VerificationEntry.fromJson(Map<String, dynamic> json) =>
      VerificationEntry(
        id: readString(json, 'id'),
        result: readString(json, 'result'),
        createdAt: readDateOrNull(json, 'createdAt') ?? DateTime.now(),
        deviceCapturedAt: readDateOrNull(json, 'deviceCapturedAt'),
        distanceFromReportM: readDoubleOrNull(json, 'distanceFromReportM'),
        distanceWarning: readBool(json, 'distanceWarning'),
        sameImageAsReport: readBool(json, 'sameImageAsReport'),
        note: readStringOrNull(json, 'note'),
        hasPhoto: readBool(json, 'hasPhoto'),
      );

  final String id;

  /// `fixed` or `not_fixed`.
  final String result;
  final DateTime createdAt;
  final DateTime? deviceCapturedAt;
  final double? distanceFromReportM;
  final bool distanceWarning;
  final bool sameImageAsReport;
  final String? note;
  final bool hasPhoto;

  bool get isFixed => result == 'fixed';
}

/// `GET /admin/complaints/{id}` (TASK-08 §5.3).
class ComplaintDetail {
  const ComplaintDetail({
    required this.summary,
    required this.latitude,
    required this.longitude,
    required this.gpsAccuracyM,
    required this.deviceCapturedAt,
    required this.exclusionNote,
    required this.excludedBy,
    required this.excludedAt,
    required this.anonymizedAt,
    required this.phoneE164,
    required this.hasPhoto,
    required this.reminders,
    required this.verifications,
  });

  factory ComplaintDetail.fromJson(Map<String, dynamic> json) =>
      ComplaintDetail(
        summary: ComplaintSummary.fromJson(json),
        latitude: readDoubleOrNull(json, 'latitude'),
        longitude: readDoubleOrNull(json, 'longitude'),
        gpsAccuracyM: readDoubleOrNull(json, 'gpsAccuracyM'),
        deviceCapturedAt: readDateOrNull(json, 'deviceCapturedAt'),
        exclusionNote: readStringOrNull(json, 'exclusionNote'),
        excludedBy: readStringOrNull(json, 'excludedBy'),
        excludedAt: readDateOrNull(json, 'excludedAt'),
        anonymizedAt: readDateOrNull(json, 'anonymizedAt'),
        phoneE164: readStringOrNull(json, 'phoneE164'),
        hasPhoto: readBool(json, 'hasPhoto'),
        reminders: readList(
          json,
          'reminders',
        ).map(ReminderEntry.fromJson).toList(growable: false),
        verifications: readList(
          json,
          'verifications',
        ).map(VerificationEntry.fromJson).toList(growable: false),
      );

  final ComplaintSummary summary;
  final double? latitude;
  final double? longitude;
  final double? gpsAccuracyM;
  final DateTime? deviceCapturedAt;
  final String? exclusionNote;
  final String? excludedBy;
  final DateTime? excludedAt;
  final DateTime? anonymizedAt;

  /// Null after anonymization.
  final String? phoneE164;
  final bool hasPhoto;
  final List<ReminderEntry> reminders;

  /// Newest first.
  final List<VerificationEntry> verifications;

  String get id => summary.id;
  bool get isAnonymized => summary.anonymized || anonymizedAt != null;

  VerificationEntry? get latestVerification =>
      verifications.isEmpty ? null : verifications.first;
}
