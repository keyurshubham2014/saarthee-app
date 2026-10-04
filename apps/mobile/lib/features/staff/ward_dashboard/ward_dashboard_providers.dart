import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/app_error.dart';
import 'rep_console_api.dart';
import 'ward_dashboard_models.dart';

/// Wards the switcher offers (server scope: own wards for representatives).
final wardScopeProvider = FutureProvider.autoDispose<List<ScopeWard>>(
  (ref) => ref.watch(repConsoleApiProvider).scope(),
  retry: _noRetry,
);

/// Screens retry explicitly ("Try again"); matches the app-wide policy.
Duration? _noRetry(int _, Object _) => null;

/// The ward chosen in the switcher (null → first scope ward).
class SelectedWard extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String wardId) => state = wardId;
}

final selectedWardProvider = NotifierProvider<SelectedWard, String?>(
  SelectedWard.new,
);

/// Last dashboard loaded per ward this session (offline fallback).
final lastGoodDashboardProvider = Provider<Map<String, WardDashboard>>(
  (ref) => <String, WardDashboard>{},
);

/// A dashboard result: fresh, or the last good one while offline.
class DashboardResult {
  const DashboardResult(this.data, {this.stale = false});

  final WardDashboard data;
  final bool stale;
}

final wardDashboardProvider = FutureProvider.autoDispose
    .family<DashboardResult, String>((ref, wardId) async {
      final cache = ref.read(lastGoodDashboardProvider);
      try {
        final d = await ref.watch(repConsoleApiProvider).dashboard(wardId);
        cache[wardId] = d;
        return DashboardResult(d);
      } catch (e) {
        final last = cache[wardId];
        if (last != null && AppError.from(e).isOffline) {
          return DashboardResult(last, stale: true);
        }
        rethrow;
      }
    }, retry: _noRetry);

/// Ward issue list for `/staff/ward/issues` (status / overdue filters).
typedef WardIssuesArgs = ({String wardId, bool overdue});

final wardIssuesProvider = FutureProvider.autoDispose
    .family<Json, WardIssuesArgs>(
      (ref, a) => ref
          .watch(repConsoleApiProvider)
          .wardIssues(a.wardId, overdue: a.overdue),
      retry: _noRetry,
    );
