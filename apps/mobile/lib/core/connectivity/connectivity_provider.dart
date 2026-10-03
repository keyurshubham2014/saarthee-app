import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// True when the device reports any network. Request failures are the
/// second signal: screens also show the offline banner on `AppError.offline`.
final isOnlineProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  bool online(List<ConnectivityResult> r) =>
      r.any((c) => c != ConnectivityResult.none);
  yield online(await connectivity.checkConnectivity());
  yield* connectivity.onConnectivityChanged.map(online);
});

/// Convenience: `true` only when connectivity is known to be offline.
final isOfflineProvider = Provider<bool>(
  (ref) => ref.watch(isOnlineProvider).value == false,
);
