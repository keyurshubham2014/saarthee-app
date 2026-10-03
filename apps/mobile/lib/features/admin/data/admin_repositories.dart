import 'dart:typed_data';

import 'admin_api.dart';
import 'models/admin_session.dart';
import 'models/complaint_detail.dart';
import 'models/complaint_summary.dart';
import 'models/rate_row.dart';
import 'models/reference_data.dart';
import 'models/reminder_result.dart';

/// `POST /admin/auth/login`, `GET /admin/me`, `POST /admin/auth/logout-all`.
class AdminAuthRepository {
  const AdminAuthRepository(this._api);
  final AdminApi _api;

  Future<AdminSession> login({
    required String email,
    required String password,
  }) async {
    final json = await _api.postJson(
      '/admin/auth/login',
      body: <String, dynamic>{'email': email.trim(), 'password': password},
      authenticated: false,
    );
    return AdminSession.fromLoginJson(json);
  }

  Future<AdminProfile> me() async =>
      AdminProfile.fromJson(await _api.getJson('/admin/me'));

  Future<void> logoutAll() async {
    await _api.postJson('/admin/auth/logout-all');
  }
}

/// Complaint list, detail, photos and complaint actions.
class AdminComplaintsRepository {
  const AdminComplaintsRepository(this._api);
  final AdminApi _api;

  static const pageSize = 50;

  Future<ComplaintPage> list(
    ComplaintFilter filter, {
    String? cursor,
    int limit = pageSize,
  }) async {
    final query = filter.toQuery()
      ..['limit'] = limit.toString()
      ..addAll(<String, dynamic>{'cursor': ?cursor});
    return ComplaintPage.fromJson(
      await _api.getJson('/admin/complaints', query: query),
    );
  }

  Future<ComplaintDetail> detail(String id) async => ComplaintDetail.fromJson(
    await _api.getJson('/admin/complaints/${Uri.encodeComponent(id)}'),
  );

  Future<Uint8List> reportPhoto(String complaintId) => _api.getBytes(
    '/admin/complaints/${Uri.encodeComponent(complaintId)}/photo',
  );

  Future<Uint8List> verificationPhoto(String verificationId) => _api.getBytes(
    '/admin/verifications/${Uri.encodeComponent(verificationId)}/photo',
  );

  Future<ReminderResult> createReminder(String complaintId) async =>
      ReminderResult.fromJson(
        await _api.postJson(
          '/admin/complaints/${Uri.encodeComponent(complaintId)}/reminders',
        ),
      );

  Future<void> revokeReminder(String reminderId) async {
    await _api.postJson(
      '/admin/reminders/${Uri.encodeComponent(reminderId)}/revoke',
    );
  }

  Future<void> setExclusion(
    String complaintId, {
    required bool isExcluded,
    String? reason,
    String? note,
  }) async {
    await _api.patchJson(
      '/admin/complaints/${Uri.encodeComponent(complaintId)}/exclusion',
      body: <String, dynamic>{
        'isExcluded': isExcluded,
        if (isExcluded && reason != null) 'reason': reason,
        if (isExcluded && note != null && note.trim().isNotEmpty)
          'note': note.trim(),
      },
    );
  }

  Future<void> anonymize(String complaintId) async {
    await _api.postJson(
      '/admin/complaints/${Uri.encodeComponent(complaintId)}/anonymize',
      body: const <String, dynamic>{'confirm': true},
    );
  }
}

/// `GET /admin/rates`.
class AdminRatesRepository {
  const AdminRatesRepository(this._api);
  final AdminApi _api;

  Future<RatesSnapshot> get() async =>
      RatesSnapshot.fromJson(await _api.getJson('/admin/rates'));
}

/// Invite codes, categories and CSV export.
class AdminReferenceRepository {
  const AdminReferenceRepository(this._api);
  final AdminApi _api;

  Future<List<InviteCode>> inviteCodes() async {
    final json = await _api.getJson('/admin/invite-codes');
    final items = json['items'];
    if (items is! List) {
      return const <InviteCode>[];
    }
    return items
        .whereType<Map<String, dynamic>>()
        .map(InviteCode.fromJson)
        .toList(growable: false);
  }

  Future<void> createInviteCode({
    String? code,
    required String sourceTag,
    required String groupLabel,
    String? wardHint,
  }) async {
    await _api.postJson(
      '/admin/invite-codes',
      body: <String, dynamic>{
        if (code != null && code.trim().isNotEmpty) 'code': code.trim(),
        'sourceTag': sourceTag,
        'groupLabel': groupLabel.trim(),
        if (wardHint != null && wardHint.trim().isNotEmpty)
          'wardHint': wardHint.trim(),
      },
    );
  }

  Future<void> setInviteCodeActive(String id, {required bool isActive}) async {
    await _api.patchJson(
      '/admin/invite-codes/${Uri.encodeComponent(id)}',
      body: <String, dynamic>{'isActive': isActive},
    );
  }

  Future<List<AdminCategory>> categories() async {
    final json = await _api.getJson('/admin/categories');
    final items = json['items'];
    if (items is! List) {
      return const <AdminCategory>[];
    }
    return items
        .whereType<Map<String, dynamic>>()
        .map(AdminCategory.fromJson)
        .toList(growable: false);
  }

  Future<void> createCategory({
    required String name,
    String? ccrsLabel,
    required int sortOrder,
  }) async {
    await _api.postJson(
      '/admin/categories',
      body: <String, dynamic>{
        'name': name.trim(),
        if (ccrsLabel != null && ccrsLabel.trim().isNotEmpty)
          'ccrsLabel': ccrsLabel.trim(),
        'sortOrder': sortOrder,
      },
    );
  }

  Future<void> updateCategory(
    String id, {
    String? name,
    String? ccrsLabel,
    int? sortOrder,
    bool? isActive,
  }) async {
    await _api.patchJson(
      '/admin/categories/${Uri.encodeComponent(id)}',
      body: <String, dynamic>{
        if (name != null) 'name': name.trim(),
        if (ccrsLabel != null) 'ccrsLabel': ccrsLabel.trim(),
        'sortOrder': ?sortOrder,
        'isActive': ?isActive,
      },
    );
  }

  /// Downloads a CSV export. Returns the suggested file name and the body.
  Future<({String fileName, String csv})> export({
    required String type,
    required bool includePhone,
  }) async {
    final result = await _api.getText(
      '/admin/export',
      query: <String, dynamic>{
        'type': type,
        'includePhone': includePhone.toString(),
      },
    );
    final disposition = result.headers.value('content-disposition') ?? '';
    final match = RegExp(r'filename="?([^";]+)"?').firstMatch(disposition);
    final fileName = match?.group(1) ?? 'saarthee-$type.csv';
    return (fileName: fileName, csv: result.body);
  }
}
