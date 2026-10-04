import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';

/// Public verification block of `GET /representatives/{id}` (TASK-11 §5.3).
class RepVerification {
  const RepVerification({
    required this.status,
    this.method,
    this.verifiedAt,
    this.validUntil,
  });

  factory RepVerification.fromJson(Map<String, dynamic>? j) => j == null
      ? const RepVerification(status: 'unverified')
      : RepVerification(
          status: '${j['status'] ?? 'unverified'}',
          method: j['method'] as String?,
          verifiedAt: DateTime.tryParse('${j['verifiedAt']}'),
          validUntil: DateTime.tryParse('${j['validUntil']}'),
        );

  /// `verified` | `unverified` | `expired`.
  final String status;
  final String? method;
  final DateTime? verifiedAt;
  final DateTime? validUntil;

  bool get isVerified => status == 'verified';
  bool get isExpired => status == 'expired';
}

/// One row of `GET /me/rep-claims`.
class MyRepClaim {
  const MyRepClaim({
    required this.claimId,
    required this.repId,
    required this.repNameEn,
    required this.repNameGu,
    required this.status,
    this.rejectReason,
  });

  factory MyRepClaim.fromJson(Map<String, dynamic> j) {
    final r = j['representative'] as Map<String, dynamic>? ?? const {};
    return MyRepClaim(
      claimId: '${j['claimId']}',
      repId: '${r['id']}',
      repNameEn: '${r['nameEn'] ?? ''}',
      repNameGu: '${r['nameGu'] ?? ''}',
      status: '${j['status']}',
      rejectReason: j['rejectReason'] as String?,
    );
  }

  final String claimId;
  final String repId;
  final String repNameEn;
  final String repNameGu;
  final String status;
  final String? rejectReason;

  String name(String lang) => lang == 'gu' ? repNameGu : repNameEn;
}

/// Citizen claim calls; every method throws `AppError`.
class RepClaimApi {
  const RepClaimApi(this._api);

  final ApiClient _api;

  /// `POST /photos` with purpose `rep_evidence`; returns the photo id.
  Future<String> uploadEvidence(
    String filePath, {
    void Function(double)? onProgress,
  }) async {
    final res = await _api.uploadFile(
      '/photos',
      filePath: filePath,
      fields: const {'purpose': 'rep_evidence'},
      onProgress: onProgress,
    );
    return '${res['photoId'] ?? res['id']}';
  }

  Future<String> submit(
    String repId,
    List<String> photoIds,
    String? note,
  ) async {
    final res = await _api.postJson(
      '/representatives/$repId/claims',
      body: {
        'evidencePhotoIds': photoIds,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
    return '${res['claimId']}';
  }

  Future<List<MyRepClaim>> mine() async {
    final res = await _api.getJson('/me/rep-claims');
    return [
      for (final i in (res['items'] as List? ?? const []))
        MyRepClaim.fromJson(i as Map<String, dynamic>),
    ];
  }

  Future<void> withdraw(String claimId) =>
      _api.deleteJson('/me/rep-claims/$claimId');
}

final repClaimApiProvider = Provider<RepClaimApi>(
  (ref) => RepClaimApi(ref.watch(apiClientProvider)),
);

final myRepClaimsProvider = FutureProvider.autoDispose<List<MyRepClaim>>(
  (ref) => ref.watch(repClaimApiProvider).mine(),
);
