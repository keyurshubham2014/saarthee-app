import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_client.dart';
import '../../../core/settings/app_settings.dart';
import 'report_draft.dart';

/// Local draft storage: JSON in shared_preferences plus the compressed photo
/// in the app documents folder (02 §5.2).
class DraftStore {
  DraftStore(this._prefs);

  final SharedPreferences _prefs;
  static const _kDraft = 'reportDraft';
  static const _kMyReports = 'myReports';
  static const _kCategories = 'lastCategories';

  ReportDraft? load() {
    final raw = _prefs.getString(_kDraft);
    if (raw == null) return null;
    try {
      final j = jsonDecode(raw);
      return j is Map<String, dynamic> ? ReportDraft.fromJson(j) : null;
    } on FormatException {
      return null;
    }
  }

  Future<void> save(ReportDraft draft) =>
      _prefs.setString(_kDraft, jsonEncode(draft.toJson()));

  Future<void> clear() => _prefs.remove(_kDraft);

  /// Moves a captured file into the draft folder and deletes the original.
  Future<String> keepPhoto(String sourcePath, String draftId) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/drafts');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final target =
        '${dir.path}/$draftId-${DateTime.now().millisecondsSinceEpoch}.jpg';
    final src = File(sourcePath);
    await src.copy(target);
    try {
      await src.delete();
    } on FileSystemException {
      // The picker's cache file may already be gone.
    }
    return target;
  }

  Future<void> deletePhoto(String? path) async {
    if (path == null) return;
    final f = File(path);
    if (f.existsSync()) await f.delete();
  }

  List<LocalReport> myReports() {
    final raw = _prefs.getString(_kMyReports);
    if (raw == null) return const [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return list.map(LocalReport.fromJson).whereType<LocalReport>().toList();
    } on FormatException {
      return const [];
    }
  }

  Future<void> addMyReport(LocalReport r) => _prefs.setString(
    _kMyReports,
    jsonEncode([r.toJson(), ...myReports().map((e) => e.toJson())]),
  );

  List<Category>? lastCategories() {
    final raw = _prefs.getString(_kCategories);
    if (raw == null) return null;
    try {
      final list = jsonDecode(raw);
      if (list is! List) return null;
      return [
        for (final c in list)
          if (c is Map) Category(id: '${c['id']}', name: '${c['name']}'),
      ];
    } on FormatException {
      return null;
    }
  }

  Future<void> saveCategories(List<Category> items) => _prefs.setString(
    _kCategories,
    jsonEncode([
      for (final c in items) {'id': c.id, 'name': c.name},
    ]),
  );
}

/// Result of POST /reports.
class SubmittedReport {
  const SubmittedReport({required this.complaintId, required this.createdAt});

  final String complaintId;
  final DateTime createdAt;
}

/// Remote calls for the report flow. All methods throw `AppError`.
class ReportRepository {
  ReportRepository(this._api);

  final ApiClient _api;

  Future<List<Category>> categories() async {
    final res = await _api.getJson('/categories');
    final items = res['items'];
    if (items is! List) return const [];
    return [
      for (final c in items)
        if (c is Map) Category(id: '${c['id']}', name: '${c['name']}'),
    ];
  }

  Future<String> uploadPhoto(
    String path, {
    void Function(double)? onProgress,
  }) async {
    final res = await _api.uploadFile(
      '/photos',
      filePath: path,
      fields: const {'purpose': 'report'},
      onProgress: onProgress,
    );
    return '${res['photoId']}';
  }

  Future<SubmittedReport> submit(Map<String, dynamic> body) async {
    final res = await _api.postJson('/reports', body: body);
    return SubmittedReport(
      complaintId: '${res['complaintId']}',
      createdAt:
          DateTime.tryParse('${res['createdAt']}') ?? DateTime.now().toUtc(),
    );
  }
}

final draftStoreProvider = Provider<DraftStore>(
  (ref) => DraftStore(ref.watch(sharedPreferencesProvider)),
);

final reportRepositoryProvider = Provider<ReportRepository>(
  (ref) => ReportRepository(ref.watch(apiClientProvider)),
);
