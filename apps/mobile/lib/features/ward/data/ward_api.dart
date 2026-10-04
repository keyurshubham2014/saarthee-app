import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import 'ward_models.dart';

/// `GET /wards/{id}/scorecard` (TASK-09 §5.2). Medians/percentages are null
/// below the minimum sample; `hidden` while election mode is on.
@immutable
class WardScorecard {
  const WardScorecard({
    required this.wardId,
    required this.hidden,
    this.until,
    this.windowDays = 90,
    this.refreshedAt,
    this.issuesReported = 0,
    this.medianDaysAck,
    this.medianDaysFix,
    this.verifiedPct,
    this.reopenPct,
    this.openBacklog = 0,
    this.reportsPer1000,
    this.population,
    this.populationSource,
  });

  final String wardId;
  final bool hidden;
  final DateTime? until;
  final int windowDays;
  final DateTime? refreshedAt;
  final int issuesReported;
  final double? medianDaysAck;
  final double? medianDaysFix;
  final double? verifiedPct;
  final double? reopenPct;
  final int openBacklog;
  final double? reportsPer1000;
  final int? population;
  final String? populationSource;

  factory WardScorecard.fromJson(Map<String, dynamic> j) {
    double? d(Object? v) => (v as num?)?.toDouble();
    final m = j['metrics'] as Map<String, dynamic>? ?? const {};
    final p = j['population'] as Map<String, dynamic>? ?? const {};
    DateTime? t(Object? v) => v == null ? null : DateTime.tryParse(v as String);
    return WardScorecard(
      wardId: j['wardId'] as String,
      hidden: j['hidden'] as bool? ?? false,
      until: t(j['until']),
      windowDays: (j['windowDays'] as num?)?.toInt() ?? 90,
      refreshedAt: t(j['refreshedAt']),
      issuesReported: (m['issuesReported'] as num?)?.toInt() ?? 0,
      medianDaysAck: d(m['medianDaysAck']),
      medianDaysFix: d(m['medianDaysFix']),
      verifiedPct: d(m['verifiedPct']),
      reopenPct: d(m['reopenPct']),
      openBacklog: (m['openBacklog'] as num?)?.toInt() ?? 0,
      reportsPer1000: d(m['reportsPer1000']),
      population: (p['value'] as num?)?.toInt(),
      populationSource: p['sourceNote'] as String?,
    );
  }
}

/// Relay request body (`POST /representatives/{id}/messages`).
@immutable
class RelayDraft {
  const RelayDraft({
    required this.clientMessageId,
    required this.subject,
    required this.body,
    required this.sharePhone,
    this.issueId,
  });

  final String clientMessageId;
  final String subject;
  final String body;
  final bool sharePhone;
  final String? issueId;

  Map<String, dynamic> toJson() => {
    'clientMessageId': clientMessageId,
    'subject': subject.trim(),
    'body': body.trim(),
    'sharePhone': sharePhone,
    if (issueId != null) 'issueId': issueId,
  };
}

/// HTTP calls for My Ward, profiles, relay and scorecard. Tests override
/// [wardApiProvider] with a fake.
abstract interface class WardApi {
  Future<WardRepresentatives> wardRepresentatives(String wardId);
  Future<RepDetail> representative(String id);
  Future<WardScorecard> scorecard(String wardId);

  /// Returns the message id. Throws `AppError` (CONSENT_REQUIRED,
  /// RATE_LIMITED, MESSAGE_LANGUAGE, REP_NO_CONTACT, OFFLINE…).
  Future<String> sendMessage(String repId, RelayDraft draft);
}

class HttpWardApi implements WardApi {
  HttpWardApi(this._api);

  final ApiClient _api;

  @override
  Future<WardRepresentatives> wardRepresentatives(String wardId) async =>
      WardRepresentatives.fromJson(
        await _api.getJson('/wards/$wardId/representatives'),
      );

  @override
  Future<RepDetail> representative(String id) async =>
      RepDetail.fromJson(await _api.getJson('/representatives/$id'));

  @override
  Future<WardScorecard> scorecard(String wardId) async =>
      WardScorecard.fromJson(await _api.getJson('/wards/$wardId/scorecard'));

  @override
  Future<String> sendMessage(String repId, RelayDraft draft) async {
    final res = await _api.postJson(
      '/representatives/$repId/messages',
      body: draft.toJson(),
    );
    return res['messageId'] as String;
  }
}

final wardApiProvider = Provider<WardApi>(
  (ref) => HttpWardApi(ref.watch(apiClientProvider)),
);
