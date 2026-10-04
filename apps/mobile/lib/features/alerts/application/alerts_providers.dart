import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/app_error.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/wards/ward_providers.dart';
import '../data/alert_models.dart';
import '../data/alerts_api.dart';
import 'alert_settings_controller.dart';
import 'in_app_alert_controller.dart';

/// Home ward + extra wards from alert settings (≤ 6 ids, `GET /alerts?wards`).
final myAlertWardIdsProvider = Provider<List<String>>((ref) {
  final home = ref.watch(homeWardProvider)?.id;
  final extra =
      ref.watch(alertSettingsProvider).value?.extraWardIds ?? const [];
  return [?home, ...extra.where((w) => w != home)].take(6).toList();
});

/// A loaded list and whether it came from the offline cache.
class AlertsList {
  const AlertsList(this.items, {this.fromCache = false});

  final List<Alert> items;
  final bool fromCache;
}

List<Alert> _parse(List<dynamic> raw) => [
  for (final a in raw) Alert.fromJson((a as Map).cast<String, dynamic>()),
];

/// Active (`true`) or past (`false`) alerts for my wards. The last loaded list
/// per tab is cached so the tab still shows it offline.
final alertsListProvider = FutureProvider.autoDispose.family<AlertsList, bool>((
  ref,
  active,
) async {
  final wards = ref.watch(myAlertWardIdsProvider);
  final prefs = ref.read(sharedPreferencesProvider);
  final key = 'saarthee.alerts.cache.${active ? 'active' : 'past'}';
  if (wards.isEmpty) return const AlertsList([]);
  try {
    final raw = await ref
        .read(alertsApiProvider)
        .listRaw(wardIds: wards, active: active);
    await prefs.setString(key, jsonEncode(raw));
    final items = _parse(raw);
    if (active) ref.read(inAppAlertProvider.notifier).onActiveList(items);
    return AlertsList(items);
  } catch (e) {
    final cached = prefs.getString(key);
    if (cached != null && AppError.from(e).isOffline) {
      return AlertsList(_parse(jsonDecode(cached) as List), fromCache: true);
    }
    rethrow;
  }
});

/// One alert; an alert opened before is cached for offline reading.
final alertDetailProvider = FutureProvider.autoDispose.family<Alert, String>((
  ref,
  id,
) async {
  final prefs = ref.read(sharedPreferencesProvider);
  final key = 'saarthee.alerts.detail.$id';
  try {
    final raw = await ref.read(alertsApiProvider).detailRaw(id);
    await prefs.setString(key, jsonEncode(raw));
    return Alert.fromJson(raw);
  } catch (e) {
    final cached = prefs.getString(key);
    if (cached != null && AppError.from(e).isOffline) {
      return Alert.fromJson(
        (jsonDecode(cached) as Map).cast<String, dynamic>(),
      );
    }
    rethrow;
  }
});
