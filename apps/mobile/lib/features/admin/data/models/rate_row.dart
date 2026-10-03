import 'json_read.dart';

/// One row of `GET /admin/rates` (03 §2.3).
class RateRow {
  const RateRow({
    required this.group,
    required this.complaints,
    required this.reminded,
    required this.verified,
    required this.h1Rate,
    required this.notFixed,
    required this.h2Rate,
  });

  factory RateRow.fromJson(Map<String, dynamic> json) => RateRow(
    group: readString(json, 'group'),
    complaints: readInt(json, 'complaints'),
    reminded: readInt(json, 'reminded'),
    verified: readInt(json, 'verified'),
    h1Rate: readDoubleOrNull(json, 'h1Rate'),
    notFixed: readInt(json, 'notFixed'),
    h2Rate: readDoubleOrNull(json, 'h2Rate'),
  );

  static const trustedGroup = 'trusted';

  /// Source tag or `trusted`.
  final String group;
  final int complaints;
  final int reminded;
  final int verified;

  /// Ratio 0..1, or null when nothing was reminded.
  final double? h1Rate;
  final int notFixed;

  /// Ratio 0..1, or null when nothing was verified.
  final double? h2Rate;

  bool get isTrusted => group == trustedGroup;
}

/// The whole rates response.
class RatesSnapshot {
  const RatesSnapshot({required this.rows, required this.computedAt});

  factory RatesSnapshot.fromJson(Map<String, dynamic> json) => RatesSnapshot(
    rows: readList(json, 'rows').map(RateRow.fromJson).toList(growable: false),
    computedAt: readDateOrNull(json, 'computedAt') ?? DateTime.now(),
  );

  final List<RateRow> rows;
  final DateTime computedAt;

  RateRow? get trusted {
    for (final row in rows) {
      if (row.isTrusted) {
        return row;
      }
    }
    return null;
  }

  List<RateRow> get sources =>
      rows.where((r) => !r.isTrusted).toList(growable: false);
}
