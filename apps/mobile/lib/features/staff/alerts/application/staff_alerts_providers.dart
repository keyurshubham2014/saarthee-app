import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/timings.dart';
import '../data/staff_alerts_api.dart';

/// Tabs of `/staff/alerts` → API `status` filter.
enum StaffAlertsTab {
  drafts('draft'),
  pending('pending_approval'),
  published('published'),
  ended('ended');

  const StaffAlertsTab(this.status);
  final String status;
}

final staffAlertsListProvider = FutureProvider.autoDispose
    .family<List<StaffAlert>, StaffAlertsTab>(
      (ref, tab) => ref.read(staffAlertsApiProvider).list(status: tab.status),
    );

final staffAlertProvider = FutureProvider.autoDispose
    .family<StaffAlert, String>(
      (ref, id) => ref.read(staffAlertsApiProvider).get(id),
    );

/// Composer fields (strings as typed; times in UTC).
class ComposerDraft {
  ComposerDraft({
    this.type = 'water_cut',
    this.severity = 'info',
    this.titleEn = '',
    this.titleGu = '',
    this.bodyEn = '',
    this.bodyGu = '',
    this.sourceName = '',
    this.sourceUrl = 'https://',
    required this.validFrom,
    required this.validTo,
    this.scope = 'wards',
    this.wardIds = const [],
    this.zoneId,
  });

  String type,
      severity,
      titleEn,
      titleGu,
      bodyEn,
      bodyGu,
      sourceName,
      sourceUrl;
  DateTime validFrom, validTo;
  String scope;
  List<String> wardIds;
  String? zoneId;

  factory ComposerDraft.from(StaffAlert a) => ComposerDraft(
    type: a.type.api,
    severity: a.severity.name,
    titleEn: a.titleEn,
    titleGu: a.titleGu,
    bodyEn: a.bodyEn,
    bodyGu: a.bodyGu,
    sourceName: a.sourceName,
    sourceUrl: a.sourceUrl,
    validFrom: a.validFrom,
    validTo: a.validTo,
    scope: a.scope,
    wardIds: a.wardIds,
    zoneId: a.zoneId,
  );

  Map<String, dynamic> toJson() => {
    'type': type,
    'severity': severity,
    'titleEn': titleEn.trim(),
    'titleGu': titleGu.trim(),
    'bodyEn': bodyEn.trim(),
    'bodyGu': bodyGu.trim(),
    'sourceName': sourceName.trim(),
    'sourceUrl': sourceUrl.trim(),
    'validFrom': validFrom.toUtc().toIso8601String(),
    'validTo': validTo.toUtc().toIso8601String(),
    'target': switch (scope) {
      'zone' => {'scope': 'zone', 'zoneId': zoneId},
      'city' => {'scope': 'city'},
      _ => {'scope': 'wards', 'wardIds': wardIds},
    },
  };
}

/// Composer problems, in form order: field → kind
/// (`required`, `tooShort`, `tooLong`, `https`, `window`). [forSubmit] also
/// requires the Gujarati fields (API 422 `ALERT_INCOMPLETE`).
Map<String, String> composerProblems(
  ComposerDraft d, {
  required DateTime now,
  bool forSubmit = false,
}) {
  final out = <String, String>{};
  void len(String field, String v, int min, int max, {bool required = true}) {
    final t = v.trim();
    if (t.isEmpty && required) {
      out[field] = 'required';
    } else if (t.length > max) {
      out[field] = 'tooLong';
    } else if (t.isNotEmpty && t.length < min) {
      out[field] = 'tooShort';
    }
  }

  len('titleEn', d.titleEn, 5, 80);
  len('titleGu', d.titleGu, 5, 80, required: forSubmit);
  len('bodyEn', d.bodyEn, 10, 500);
  len('bodyGu', d.bodyGu, 10, 500, required: forSubmit);
  len('sourceName', d.sourceName, 2, 80);
  if (!RegExp(r'^https://\S+$').hasMatch(d.sourceUrl.trim()) ||
      d.sourceUrl.length > 500) {
    out['sourceUrl'] = 'https';
  }
  final span = d.validTo.difference(d.validFrom);
  if (!d.validTo.isAfter(now) ||
      span <= Duration.zero ||
      span > AppTimings.alertMaxValidity) {
    out['validTo'] = 'window';
  }
  if (d.scope == 'wards' && d.wardIds.isEmpty) out['area'] = 'required';
  if (d.scope == 'zone' && d.zoneId == null) out['area'] = 'required';
  return out;
}
