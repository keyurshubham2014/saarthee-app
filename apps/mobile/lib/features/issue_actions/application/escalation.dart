import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/issue_models.dart';

/// Ladder order (TASK-06 §5.3).
const escalationLevels = [
  'corporators',
  'zone_office',
  'deputy_commissioner',
  'commissioner',
];

/// Mirrors the server: corporators until the first escalation; the next
/// level once the highest one used is ≥ 7 days old and the issue is overdue.
String recommendedEscalation(
  List<IssueEventItem> events, {
  required bool overdue,
  required DateTime now,
}) {
  final used = [
    for (final e in events)
      if (e.type == 'escalated' && escalationLevels.contains(e.level)) e,
  ];
  if (used.isEmpty) return 'corporators';
  var idx = 0;
  for (final e in used) {
    idx = escalationLevels.indexOf(e.level!) > idx
        ? escalationLevels.indexOf(e.level!)
        : idx;
  }
  final level = escalationLevels[idx];
  DateTime? last;
  for (final e in used.where((e) => e.level == level)) {
    final at = e.createdAt;
    if (at != null && (last == null || at.isAfter(last))) last = at;
  }
  final weekOld = last != null && now.difference(last).inDays >= 7;
  if (overdue && weekOld && idx < escalationLevels.length - 1) {
    return escalationLevels[idx + 1];
  }
  return level;
}

/// External actions of the escalate screen (fake in tests).
class EscalationLauncher {
  const EscalationLauncher();

  Future<bool> email(String to, String subject, String body) => launchUrl(
    Uri(
      scheme: 'mailto',
      path: to,
      query: _query({'subject': subject, 'body': body}),
    ),
  );

  Future<bool> call(String phone) => launchUrl(Uri(scheme: 'tel', path: phone));

  Future<void> share(String text) =>
      SharePlus.instance.share(ShareParams(text: text));

  Future<void> copy(String text) =>
      Clipboard.setData(ClipboardData(text: text));

  Future<bool> openUrl(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  static String _query(Map<String, String> p) => p.entries
      .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
      .join('&');
}

final escalationLauncherProvider = Provider<EscalationLauncher>(
  (ref) => const EscalationLauncher(),
);
