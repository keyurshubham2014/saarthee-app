import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';

/// GET /verify/complaint summary. Never contains phone, coordinates,
/// invite code or source tag.
class VerifySummary {
  const VerifySummary({
    required this.complaintId,
    required this.categoryName,
    required this.ccrsNumber,
    required this.reportedAt,
    required this.hasPhoto,
    required this.previousVerificationCount,
  });

  final String complaintId;
  final String categoryName;
  final String ccrsNumber;
  final DateTime reportedAt;
  final bool hasPhoto;
  final int previousVerificationCount;
}

/// Verify endpoints. The token is passed ONLY as the `X-Verify-Token`
/// header — never in a path, query string or log. All methods throw
/// `AppError`.
class VerifyRepository {
  VerifyRepository(this._api);

  final ApiClient _api;

  Map<String, String> _h(String token) => {'X-Verify-Token': token};

  Future<VerifySummary> complaint(String token) async {
    final j = await _api.getJson('/verify/complaint', headers: _h(token));
    return VerifySummary(
      complaintId: '${j['complaintId']}',
      categoryName: '${j['categoryName'] ?? ''}',
      ccrsNumber: '${j['ccrsNumber'] ?? ''}',
      reportedAt:
          DateTime.tryParse('${j['reportedAt']}') ?? DateTime.now().toUtc(),
      hasPhoto: j['hasPhoto'] == true,
      previousVerificationCount:
          (j['previousVerificationCount'] as num?)?.toInt() ?? 0,
    );
  }

  Future<Uint8List> reportPhoto(String token) async {
    final bytes = await _api.getBytes(
      '/verify/complaint/photo',
      headers: _h(token),
    );
    return Uint8List.fromList(bytes);
  }

  Future<String> uploadPhoto(
    String token,
    String path, {
    void Function(double)? onProgress,
  }) async {
    final res = await _api.uploadFile(
      '/verify/photos',
      filePath: path,
      headers: _h(token),
      onProgress: onProgress,
    );
    return '${res['photoId']}';
  }

  Future<void> submit(String token, Map<String, dynamic> body) =>
      _api.postJson('/verify/submissions', body: body, headers: _h(token));
}

final verifyRepositoryProvider = Provider<VerifyRepository>(
  (ref) => VerifyRepository(ref.watch(apiClientProvider)),
);
