import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/app_error.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/wards/ward.dart';
import '../../../core/wards/wards_repository.dart';
import '../data/report_api.dart';
import '../data/report_models.dart';

export '../data/report_models.dart';

const String kCategoriesCacheKey = 'v2.reportCategories';

class CategoriesResult {
  const CategoriesResult(this.items, {this.fromCache = false});

  final List<ReportCategory> items;

  /// Served from the device cache because the network failed.
  final bool fromCache;

  ReportCategory? bySlug(String? slug) {
    for (final c in items) {
      if (c.slug == slug) return c;
    }
    return null;
  }
}

/// `GET /categories`, cached on the device; offline → the cached list.
final reportCategoriesProvider = FutureProvider<CategoriesResult>((ref) async {
  final prefs = ref.read(sharedPreferencesProvider);
  try {
    final items = await ref.read(reportApiProvider).categories();
    await prefs.setString(
      kCategoriesCacheKey,
      jsonEncode([for (final c in items) c.toJson()]),
    );
    return CategoriesResult(items);
  } on AppError catch (e) {
    final raw = prefs.getString(kCategoriesCacheKey);
    if (raw == null || !e.isOffline) rethrow;
    final cached = [
      for (final c in jsonDecode(raw) as List)
        ReportCategory.fromJson(Map<String, dynamic>.from(c as Map)),
    ];
    return CategoriesResult(cached, fromCache: true);
  }
});

/// Duplicate suggestions for a pin + category (TASK-05 §5.3).
typedef NearbyKey = ({String slug, double lat, double lng});

final nearbyIssuesProvider = FutureProvider.autoDispose
    .family<List<NearbyIssue>, NearbyKey>(
      (ref, k) => ref.read(reportApiProvider).nearby(k.lat, k.lng, k.slug),
    );

/// Ward for a pin; null when the place is outside the service area.
typedef PinKey = ({double lat, double lng});

final pinWardProvider = FutureProvider.autoDispose
    .family<WardLocateResult?, PinKey>((ref, k) async {
      try {
        return await ref.read(wardsRepositoryProvider).locate(k.lat, k.lng);
      } on OutsideServiceArea {
        return null;
      }
    });

/// One-shot report actions used by the screens (no API client in
/// presentation/).
class ReportActions {
  const ReportActions(this._api);

  final ReportApi _api;

  Future<int> meToo(String issueId) => _api.meToo(issueId);

  Future<void> linkCcrs(String issueId, String number, String filedVia) =>
      _api.linkCcrs(issueId, number, filedVia);
}

final reportActionsProvider = Provider<ReportActions>(
  (ref) => ReportActions(ref.watch(reportApiProvider)),
);

/// Drafts whose pin already dropped (the pin drops once per draft).
class PinDroppedController extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void mark(String draftId) => state = {...state, draftId};
}

final pinDroppedProvider = NotifierProvider<PinDroppedController, Set<String>>(
  PinDroppedController.new,
);

/// The issue just submitted, read by `/report/done`.
class LastSubmissionController extends Notifier<SubmittedIssue?> {
  @override
  SubmittedIssue? build() => null;

  void set(SubmittedIssue? issue) => state = issue;
}

final lastSubmissionProvider =
    NotifierProvider<LastSubmissionController, SubmittedIssue?>(
      LastSubmissionController.new,
    );
