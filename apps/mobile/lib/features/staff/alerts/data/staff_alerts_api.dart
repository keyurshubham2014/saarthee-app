import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/theme/tokens.dart';
import '../../../alerts/data/alert_models.dart';

/// One approval in the panel.
class StaffApproval {
  const StaffApproval({required this.actorId, this.name, required this.role});

  final String actorId;
  final String? name;
  final String role;
}

/// `StaffAlertDto` (TASK-08 §5.3).
class StaffAlert {
  const StaffAlert({
    required this.id,
    required this.type,
    required this.severity,
    required this.titleEn,
    required this.titleGu,
    required this.bodyEn,
    required this.bodyGu,
    required this.sourceName,
    required this.sourceUrl,
    required this.validFrom,
    required this.validTo,
    required this.scope,
    required this.wardIds,
    required this.status,
    required this.origin,
    required this.approvals,
    required this.approvalsNeeded,
    this.zoneId,
    this.updatedAt,
  });

  final String id;
  final AlertType type;
  final AlertSeverity severity;
  final String titleEn, titleGu, bodyEn, bodyGu, sourceName, sourceUrl;
  final DateTime validFrom, validTo;
  final String scope;
  final List<String> wardIds;
  final String? zoneId;

  /// draft, pending_approval, published, expired, retracted.
  final String status;
  final String origin;
  final List<StaffApproval> approvals;
  final int approvalsNeeded;
  final DateTime? updatedAt;

  bool get editable => status == 'draft' || status == 'pending_approval';

  factory StaffAlert.fromJson(Map<String, dynamic> j) {
    final target = (j['target'] as Map).cast<String, dynamic>();
    return StaffAlert(
      id: j['id'] as String,
      type: AlertType.parse(j['type']),
      severity: parseSeverity(j['severity']),
      titleEn: j['titleEn'] as String? ?? '',
      titleGu: j['titleGu'] as String? ?? '',
      bodyEn: j['bodyEn'] as String? ?? '',
      bodyGu: j['bodyGu'] as String? ?? '',
      sourceName: j['sourceName'] as String? ?? '',
      sourceUrl: j['sourceUrl'] as String? ?? '',
      validFrom: DateTime.parse(j['validFrom'] as String),
      validTo: DateTime.parse(j['validTo'] as String),
      scope: target['scope'] as String? ?? 'city',
      wardIds: [
        for (final w in (target['wardIds'] as List? ?? const [])) w as String,
      ],
      zoneId: target['zoneId'] as String?,
      status: j['effectiveStatus'] as String? ?? j['status'] as String,
      origin: j['origin'] as String? ?? 'manual',
      approvals: [
        for (final a in (j['approvals'] as List? ?? const []))
          StaffApproval(
            actorId: (a as Map)['actorId'] as String,
            name: a['name'] as String?,
            role: a['role'] as String? ?? '',
          ),
      ],
      approvalsNeeded: (j['approvalsNeeded'] as num?)?.toInt() ?? 1,
      updatedAt: j['updatedAt'] == null
          ? null
          : DateTime.parse(j['updatedAt'] as String),
    );
  }
}

/// `/staff/alerts*` (moderator/admin session; the interceptor adds the token).
class StaffAlertsApi {
  StaffAlertsApi(this._api);

  final ApiClient _api;

  Future<List<StaffAlert>> list({String? status}) async {
    final j = await _api.getJson('/staff/alerts', query: {'status': ?status});
    return [
      for (final a in (j['items'] as List? ?? const []))
        StaffAlert.fromJson((a as Map).cast<String, dynamic>()),
    ];
  }

  Future<StaffAlert> get(String id) async =>
      StaffAlert.fromJson(await _api.getJson('/staff/alerts/$id'));

  Future<StaffAlert> create(Map<String, dynamic> body) async =>
      StaffAlert.fromJson(await _api.postJson('/staff/alerts', body: body));

  Future<StaffAlert> update(String id, Map<String, dynamic> body) async =>
      StaffAlert.fromJson(
        await _api.patchJson('/staff/alerts/$id', body: body),
      );

  /// submit | approve | publish | retract | supersede.
  Future<Map<String, dynamic>> action(
    String id,
    String action, {
    Map<String, dynamic>? body,
  }) => _api.postJson('/staff/alerts/$id/$action', body: body ?? const {});
}

final staffAlertsApiProvider = Provider<StaffAlertsApi>(
  (ref) => StaffAlertsApi(ref.watch(apiClientProvider)),
);
