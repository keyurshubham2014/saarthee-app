import 'json_read.dart';

/// `POST /admin/complaints/{id}/reminders` response. Holds the phone number
/// and the one-time verify link: keep in memory only, never log or persist.
class ReminderResult {
  const ReminderResult({
    required this.reminderId,
    required this.sentAt,
    required this.verifyLink,
    required this.messageText,
    required this.phoneE164,
  });

  factory ReminderResult.fromJson(Map<String, dynamic> json) => ReminderResult(
    reminderId: readString(json, 'reminderId'),
    sentAt: readDateOrNull(json, 'sentAt') ?? DateTime.now(),
    verifyLink: readString(json, 'verifyLink'),
    messageText: readString(json, 'messageText'),
    phoneE164: readString(json, 'phoneE164'),
  );

  final String reminderId;
  final DateTime sentAt;
  final String verifyLink;
  final String messageText;
  final String phoneE164;

  @override
  String toString() => 'ReminderResult($reminderId)';
}
