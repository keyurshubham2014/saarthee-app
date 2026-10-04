import 'package:intl/intl.dart';

import '../../config/timings.dart';
import '../../l10n/app_localizations.dart';

/// India Standard Time (fixed +05:30). Alerts are always shown in
/// Asia/Kolkata whatever the phone's zone (TASK-08 §5.3).
DateTime toIst(DateTime t) => t.toUtc().add(AppTimings.istOffset);

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// "Today 10:00–16:00", "Until Sat 5 Oct, 18:00" or "Sat 5 Oct, 10:00 – Sun
/// 6 Oct, 18:00", locale-aware (gu/en), in IST.
String formatAlertValidity(
  AppLocalizations l10n,
  String locale,
  DateTime from,
  DateTime to, {
  DateTime? now,
}) {
  final f = toIst(from);
  final t = toIst(to);
  final n = toIst(now ?? DateTime.now());
  final time = DateFormat('HH:mm', locale);
  final dayTime = DateFormat('EEE d MMM, HH:mm', locale);
  if (_sameDay(f, t) && _sameDay(f, n)) {
    return l10n.alertsValidityToday(time.format(f), time.format(t));
  }
  if (!f.isAfter(n)) return l10n.alertsValidityUntil(dayTime.format(t));
  if (_sameDay(f, t)) {
    return l10n.alertsValidityRange(dayTime.format(f), time.format(t));
  }
  return l10n.alertsValidityRange(dayTime.format(f), dayTime.format(t));
}

/// "Sat 5 Oct, 18:00" (IST) — end time for TalkBack labels.
String formatAlertEnd(String locale, DateTime to) =>
    DateFormat('EEE d MMM, HH:mm', locale).format(toIst(to));

/// Inbox row time: "14:05" today, else "5 Oct".
String formatInboxTime(String locale, DateTime at, {DateTime? now}) {
  final a = toIst(at);
  final n = toIst(now ?? DateTime.now());
  return _sameDay(a, n)
      ? DateFormat('HH:mm', locale).format(a)
      : DateFormat('d MMM', locale).format(a);
}

/// Whether [at] is "Today" in IST (inbox grouping).
bool isIstToday(DateTime at, {DateTime? now}) =>
    _sameDay(toIst(at), toIst(now ?? DateTime.now()));
