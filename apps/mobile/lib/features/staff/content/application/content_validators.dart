import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/utils/formatters.dart';

/// Client-side checks that mirror the API's Zod rules (TASK-12 §5.3).
class ContentValidators {
  const ContentValidators(this.l10n);

  final AppLocalizations l10n;

  static final _slug = RegExp(r'^[a-z0-9-]{3,60}$');
  static final _https = RegExp(r'^https://\S+$');
  static final _step = RegExp(r'^\d{1,2}\. \S');
  static final _date = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  static final _dateTime = RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$');

  String? required(String v, {int max = 1000}) {
    final t = v.trim();
    if (t.isEmpty) return l10n.staffContentErrorRequired;
    if (t.length > max) return l10n.staffContentErrorRequired;
    return null;
  }

  String? slug(String v) =>
      _slug.hasMatch(v.trim()) ? null : l10n.staffContentErrorSlug;

  String? https(String v) =>
      _https.hasMatch(v.trim()) ? null : l10n.staffContentErrorHttps;

  String? optionalHttps(String v) => v.trim().isEmpty ? null : https(v);

  /// Every non-empty line is "N. step".
  String? steps(String v) {
    final lines = v.trim().split('\n').where((l) => l.trim().isNotEmpty);
    if (lines.isEmpty) return l10n.staffContentErrorRequired;
    return lines.every((l) => _step.hasMatch(l.trim()))
        ? null
        : l10n.staffContentErrorSteps;
  }

  String? wholeNumber(String v, {bool optional = false}) {
    if (optional && v.trim().isEmpty) return null;
    return int.tryParse(v.trim()) == null ? l10n.staffContentErrorNumber : null;
  }

  String? date(String v) =>
      _date.hasMatch(v.trim()) && DateTime.tryParse(v.trim()) != null
      ? null
      : l10n.staffContentErrorDate;

  String? dateTime(String v) =>
      _dateTime.hasMatch(v.trim()) &&
          DateTime.tryParse(v.trim().replaceFirst(' ', 'T')) != null
      ? null
      : l10n.staffContentErrorDate;
}

/// IST offset from UTC, from the shared formatter (no literal here).
final _istOffset = Formatters.toIst(DateTime.utc(2000))
    .difference(DateTime.utc(2000));

/// "2026-10-12 07:00" entered in IST → UTC ISO-8601 for the API.
String istInputToIso(String v) {
  final local = DateTime.parse('${v.trim().replaceFirst(' ', 'T')}:00Z');
  return local.subtract(_istOffset).toIso8601String();
}

/// UTC ISO-8601 → "2026-10-12 07:00" (IST) for the form.
String isoToIstInput(String? iso) {
  final d = DateTime.tryParse(iso ?? '');
  if (d == null) return '';
  final ist = Formatters.toIst(d);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${ist.year}-${two(ist.month)}-${two(ist.day)} ${two(ist.hour)}:${two(ist.minute)}';
}
