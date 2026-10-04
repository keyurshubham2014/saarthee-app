import 'package:flutter/foundation.dart';

/// Flutter build mode, as a value so the URL policy can be unit-tested for
/// every mode (F-13-01).
enum BuildMode { debug, profile, release }

BuildMode get currentBuildMode {
  if (kReleaseMode) return BuildMode.release;
  if (kProfileMode) return BuildMode.profile;
  return BuildMode.debug;
}

/// Hosts that may use plain HTTP, in debug and profile builds only: the Android
/// emulator's alias for the dev machine and localhost. Matches the debug and
/// profile `network_security_config.xml`. Profile builds are never distributed;
/// they are the integrator's emulator verification build (debug cold starts ANR
/// on the reference emulator), so they need the emulator alias. Release: HTTPS only.
const Set<String> debugCleartextHosts = {'10.0.2.2', 'localhost'};

/// Optional extra debug-only HTTP host (a dev machine's LAN IP for a physical
/// phone, `scripts/run-lan-phone.sh`): `--dart-define=DEV_CLEARTEXT_HOST=<ip>`.
/// The same IP must be added locally to the debug network security config.
const String devCleartextHost = String.fromEnvironment('DEV_CLEARTEXT_HOST');

/// HTTPS everywhere outside local (V2 TASK-13, REQ-S-013, Spec §12):
/// - `https://<host>` is allowed in every build mode;
/// - `http://` is allowed only in debug builds and only for
///   [debugCleartextHosts] (plus [extraDebugHosts], default
///   [devCleartextHost]);
/// - anything else (empty, relative, other schemes, missing host) is refused.
bool apiBaseUrlIsAllowed(
  String url,
  BuildMode mode, {
  Set<String> extraDebugHosts = const {
    if (devCleartextHost != '') devCleartextHost,
  },
}) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) return false;
  if (uri.userInfo.isNotEmpty) return false;
  switch (uri.scheme) {
    case 'https':
      return true;
    case 'http':
      final host = uri.host.toLowerCase();
      if (mode == BuildMode.release) return false;
      if (debugCleartextHosts.contains(host)) return true;
      return mode == BuildMode.debug && extraDebugHosts.contains(host);
    default:
      return false;
  }
}
