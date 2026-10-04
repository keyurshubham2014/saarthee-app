import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/app_settings.dart';
import '../../../core/wards/ward_providers.dart';
import '../data/service_models.dart';
import '../data/services_repository.dart';

/// Whole directory (≈ 20 rows); category and search filter on device so
/// they also work on the offline cache.
final servicesListProvider =
    FutureProvider.autoDispose<Cached<List<ServiceSummary>>>(
      (ref) => ref.watch(servicesRepositoryProvider).listServices(),
    );

/// Service detail with the home ward's office.
final serviceDetailProvider = FutureProvider.autoDispose
    .family<ServiceDetail, String>((ref, slug) {
      final wardId = ref.watch(homeWardProvider.select((w) => w?.id));
      return ref
          .watch(servicesRepositoryProvider)
          .getService(slug, wardId: wardId);
    });

/// Seasonal tips for Home (home ward first).
final serviceTipsProvider = FutureProvider.autoDispose<List<ServiceTip>>((
  ref,
) async {
  final wardId = ref.watch(homeWardProvider.select((w) => w?.id));
  final res = await ref.watch(servicesRepositoryProvider).tips(wardId: wardId);
  return res.value;
});

/// Tip ids the user dismissed on this device (`v2.dismissedTips`).
class DismissedTipsController extends Notifier<Set<String>> {
  @override
  Set<String> build() =>
      (ref
                  .watch(sharedPreferencesProvider)
                  .getStringList(ServicesPrefKeys.dismissedTips) ??
              const <String>[])
          .toSet();

  Future<void> dismiss(String id) async {
    state = {...state, id};
    await ref
        .read(sharedPreferencesProvider)
        .setStringList(ServicesPrefKeys.dismissedTips, state.toList());
  }
}

final dismissedTipsProvider =
    NotifierProvider<DismissedTipsController, Set<String>>(
      DismissedTipsController.new,
    );

/// Filters [items] by category (null = all) and a case-insensitive query on
/// both languages' name and summary.
List<ServiceSummary> filterServices(
  List<ServiceSummary> items, {
  String? category,
  String query = '',
}) {
  final q = query.trim().toLowerCase();
  return items.where((s) {
    if (category != null && s.category != category) return false;
    if (q.isEmpty) return true;
    return [
      s.nameEn,
      s.nameGu,
      s.summaryEn,
      s.summaryGu,
    ].any((t) => t.toLowerCase().contains(q));
  }).toList();
}
