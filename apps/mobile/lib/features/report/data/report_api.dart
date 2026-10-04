import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import 'report_models.dart';

/// Report endpoints (TASK-05 §5.3). Screens never import this directly; they
/// go through the application providers.
abstract interface class ReportApi {
  Future<List<ReportCategory>> categories();

  /// `POST /photos` (signed in). Returns the photo id.
  Future<String> uploadPhoto(
    String filePath, {
    required bool blurApplied,
    void Function(double progress)? onProgress,
  });

  Future<List<NearbyIssue>> nearby(double lat, double lng, String slug);

  /// `POST /issues`; 201 and 200 (repeat) are both success.
  Future<Map<String, dynamic>> submit(Map<String, Object?> body);

  Future<int> meToo(String issueId);

  Future<void> linkCcrs(String issueId, String number, String filedVia);
}

class HttpReportApi implements ReportApi {
  HttpReportApi(this._api);

  final ApiClient _api;

  @override
  Future<List<ReportCategory>> categories() async {
    final res = await _api.getJson('/categories');
    return [
      for (final c in (res['items'] as List? ?? const []))
        ReportCategory.fromJson(Map<String, dynamic>.from(c as Map)),
    ];
  }

  @override
  Future<String> uploadPhoto(
    String filePath, {
    required bool blurApplied,
    void Function(double progress)? onProgress,
  }) async {
    final res = await _api.uploadFile(
      '/photos',
      filePath: filePath,
      fields: {'purpose': 'report', 'blurApplied': '$blurApplied'},
      onProgress: onProgress,
    );
    return res['photoId'] as String;
  }

  @override
  Future<List<NearbyIssue>> nearby(double lat, double lng, String slug) async {
    final res = await _api.getJson(
      '/issues/nearby',
      query: {'lat': '$lat', 'lng': '$lng', 'category': slug},
    );
    return [
      for (final i in (res['items'] as List? ?? const []))
        NearbyIssue.fromJson(Map<String, dynamic>.from(i as Map)),
    ];
  }

  @override
  Future<Map<String, dynamic>> submit(Map<String, Object?> body) =>
      _api.postJson('/issues', body: body);

  @override
  Future<int> meToo(String issueId) async {
    final res = await _api.postJson('/issues/$issueId/me-too');
    return (res['meTooCount'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<void> linkCcrs(String issueId, String number, String filedVia) =>
      _api.postJson(
        '/issues/$issueId/ccrs',
        body: {'ccrsNumber': number, 'filedVia': filedVia},
      );
}

final reportApiProvider = Provider<ReportApi>(
  (ref) => HttpReportApi(ref.watch(apiClientProvider)),
);
