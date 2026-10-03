import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../data/models/reference_data.dart';
import 'admin_auth.dart';

/// `inviteCodesProvider` (02 §5.2).
final inviteCodesProvider = FutureProvider<List<InviteCode>>(
  (ref) => ref.read(adminReferenceRepositoryProvider).inviteCodes(),
  retry: (_, _) => null,
);

/// `adminCategoriesProvider` (02 §5.2): all categories incl. inactive,
/// ordered by sort order then name.
final adminCategoriesProvider = FutureProvider<List<AdminCategory>>((
  ref,
) async {
  final items = await ref.read(adminReferenceRepositoryProvider).categories();
  final sorted = [...items]
    ..sort((a, b) {
      final bySort = a.sortOrder.compareTo(b.sortOrder);
      return bySort != 0 ? bySort : a.name.compareTo(b.name);
    });
  return sorted;
}, retry: (_, _) => null);

/// Reference-data mutations. Each refreshes the affected provider.
final adminReferenceActionsProvider = Provider<AdminReferenceActions>(
  AdminReferenceActions.new,
);

class AdminReferenceActions {
  AdminReferenceActions(this._ref);
  final Ref _ref;

  Future<void> createInviteCode({
    String? code,
    required String sourceTag,
    required String groupLabel,
    String? wardHint,
  }) async {
    await _ref
        .read(adminReferenceRepositoryProvider)
        .createInviteCode(
          code: code,
          sourceTag: sourceTag,
          groupLabel: groupLabel,
          wardHint: wardHint,
        );
    _ref.invalidate(inviteCodesProvider);
  }

  Future<void> setInviteCodeActive(String id, {required bool isActive}) async {
    await _ref
        .read(adminReferenceRepositoryProvider)
        .setInviteCodeActive(id, isActive: isActive);
    _ref.invalidate(inviteCodesProvider);
  }

  Future<void> createCategory({
    required String name,
    String? ccrsLabel,
    required int sortOrder,
  }) async {
    await _ref
        .read(adminReferenceRepositoryProvider)
        .createCategory(name: name, ccrsLabel: ccrsLabel, sortOrder: sortOrder);
    _ref.invalidate(adminCategoriesProvider);
  }

  Future<void> updateCategory(
    String id, {
    String? name,
    String? ccrsLabel,
    int? sortOrder,
    bool? isActive,
  }) async {
    await _ref
        .read(adminReferenceRepositoryProvider)
        .updateCategory(
          id,
          name: name,
          ccrsLabel: ccrsLabel,
          sortOrder: sortOrder,
          isActive: isActive,
        );
    _ref.invalidate(adminCategoriesProvider);
  }

  /// Renumbers [ordered] in steps of 10 and patches only the categories
  /// whose sort order changed (TASK-09 §5.6). Always refreshes afterwards,
  /// so a failure puts the server order back on screen.
  Future<void> reorderCategories(List<AdminCategory> ordered) async {
    final repo = _ref.read(adminReferenceRepositoryProvider);
    try {
      for (var i = 0; i < ordered.length; i++) {
        final target = (i + 1) * 10;
        if (ordered[i].sortOrder != target) {
          await repo.updateCategory(ordered[i].id, sortOrder: target);
        }
      }
    } finally {
      _ref.invalidate(adminCategoriesProvider);
    }
  }

  /// Downloads a CSV and saves it on the device. Returns the saved file.
  Future<File> exportCsv({
    required String type,
    required bool includePhone,
  }) async {
    final result = await _ref
        .read(adminReferenceRepositoryProvider)
        .export(type: type, includePhone: includePhone);
    Directory? dir;
    try {
      dir = await getDownloadsDirectory();
    } on Object {
      dir = null;
    }
    dir ??= await getApplicationDocumentsDirectory();
    final safeName = result.fileName.replaceAll(
      RegExp(r'[^A-Za-z0-9._-]'),
      '_',
    );
    final file = File('${dir.path}${Platform.pathSeparator}$safeName');
    await file.writeAsString(result.csv, flush: true);
    return file;
  }
}
