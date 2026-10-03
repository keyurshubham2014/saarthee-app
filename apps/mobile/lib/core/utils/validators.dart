/// Shared validators mirroring backend rules (03 §4.2). The server stays
/// authoritative. Each returns `true` when valid; screens map to ARB text.
class Validators {
  const Validators._();

  static final RegExp _inviteCode = RegExp(r'^[A-Z0-9]{6,20}$');

  static bool inviteCode(String value) =>
      _inviteCode.hasMatch(value.trim().toUpperCase());

  /// Required, 1–50 characters after trimming.
  static bool ccrsNumber(String value) {
    final t = value.trim();
    return t.isNotEmpty && t.length <= 50;
  }

  /// Ten-digit Indian mobile number starting 6–9, after normalization.
  static bool indianMobile(String value) => normalizePhone(value) != null;

  /// Removes spaces/dashes and an optional +91, 91 or 0 prefix; returns the
  /// 10 digits or null when invalid.
  static String? normalizePhone(String value) {
    var digits = value.replaceAll(RegExp(r'[\s-]'), '');
    if (digits.startsWith('+91')) {
      digits = digits.substring(3);
    } else if (digits.length == 12 && digits.startsWith('91')) {
      digits = digits.substring(2);
    } else if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return RegExp(r'^[6-9]\d{9}$').hasMatch(digits) ? digits : null;
  }

  /// Note ≤ 1,000 characters.
  static bool note(String value) => value.length <= 1000;
}
