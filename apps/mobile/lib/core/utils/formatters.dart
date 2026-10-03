import 'package:intl/intl.dart';

/// Display helpers (02 §2.4): times in IST, phone as +91 98765 43210.
class Formatters {
  const Formatters._();

  static const Duration _istOffset = Duration(hours: 5, minutes: 30);

  /// Converts any instant to IST wall-clock time (no tz database needed;
  /// India has no daylight saving).
  static DateTime toIst(DateTime instant) => instant.toUtc().add(_istOffset);

  /// "3 Oct 2026, 10:42 am" in IST.
  static String dateTime(DateTime instant, [String? locale]) {
    final ist = toIst(instant);
    final date = DateFormat.yMMMd(locale).format(ist);
    final time = DateFormat.jm(locale).format(ist).toLowerCase();
    return '$date, $time';
  }

  /// "3 Oct" in IST.
  static String shortDate(DateTime instant, [String? locale]) =>
      DateFormat.MMMd(locale).format(toIst(instant));

  /// "3 Oct 2026" in IST.
  static String date(DateTime instant, [String? locale]) =>
      DateFormat.yMMMd(locale).format(toIst(instant));

  /// "+91 98765 43210" from 10 digits or E.164.
  static String phone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    final local = digits.length > 10
        ? digits.substring(digits.length - 10)
        : digits;
    if (local.length != 10) return value;
    return '+91 ${local.substring(0, 5)} ${local.substring(5)}';
  }
}
