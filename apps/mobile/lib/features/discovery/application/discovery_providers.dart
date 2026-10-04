import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/app_error.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/settings/locale_controller.dart';
import '../data/discovery_api.dart';
import '../data/discovery_models.dart';

/// Home feed for a ward: the nearby issues (`GET /feed`). Alerts come from
/// TASK-08's provider; drives and services from TASK-12's sections.
class HomeFeed {
  const HomeFeed({required this.nearby, this.cachedAt});

  final List<IssueCardData> nearby;

  /// Set when the network failed and the last good feed is shown.
  final DateTime? cachedAt;

  int get openCount => nearby.length;
  int get overdueCount => nearby.where((i) => i.isOverdue).length;
  int get affected => nearby.fold(0, (s, i) => s + i.meTooCount);
}

List<IssueCardData> _nearbyFrom(Map<String, dynamic> raw) {
  final sections = Map<String, dynamic>.from(raw['sections'] as Map? ?? {});
  final nearby = Map<String, dynamic>.from(
    sections['nearbyIssues'] as Map? ?? const {},
  );
  return [
    for (final i in (nearby['items'] as List? ?? const []))
      IssueCardData.fromJson(Map<String, dynamic>.from(i as Map)),
  ];
}

/// Last good feed per ward + language is kept for offline reading.
final homeFeedProvider = FutureProvider.autoDispose.family<HomeFeed, String>((
  ref,
  wardId,
) async {
  final lang = ref.watch(localeProvider).languageCode;
  final prefs = ref.read(sharedPreferencesProvider);
  final key = 'saarthee.feed.cache.$wardId.$lang';
  try {
    final raw = await ref.read(discoveryApiProvider).feedRaw(wardId, lang);
    await prefs.setString(
      key,
      jsonEncode({'at': DateTime.now().toIso8601String(), 'feed': raw}),
    );
    return HomeFeed(nearby: _nearbyFrom(raw));
  } catch (e) {
    final cached = prefs.getString(key);
    if (cached != null && AppError.from(e).isOffline) {
      final j = jsonDecode(cached) as Map<String, dynamic>;
      return HomeFeed(
        nearby: _nearbyFrom(Map<String, dynamic>.from(j['feed'] as Map)),
        cachedAt: DateTime.tryParse(j['at'] as String? ?? ''),
      );
    }
    rethrow;
  }
});

/// Issue detail; an issue opened before is cached for offline reading
/// (actions are then disabled).
class LoadedDetail {
  const LoadedDetail(this.issue, {this.fromCache = false});

  final IssueDetail issue;
  final bool fromCache;
}

final issueDetailProvider = FutureProvider.autoDispose
    .family<LoadedDetail, String>((ref, id) async {
      final lang = ref.watch(localeProvider).languageCode;
      final prefs = ref.read(sharedPreferencesProvider);
      final key = 'saarthee.issue.cache.$id.$lang';
      try {
        final raw = await ref.read(discoveryApiProvider).detailRaw(id, lang);
        final issue = IssueDetail.fromJson(raw);
        await prefs.setString(key, jsonEncode(raw));
        return LoadedDetail(issue);
      } catch (e) {
        final cached = prefs.getString(key);
        if (cached != null && AppError.from(e).isOffline) {
          return LoadedDetail(
            IssueDetail.fromJson(jsonDecode(cached) as Map<String, dynamic>),
            fromCache: true,
          );
        }
        rethrow;
      }
    });
