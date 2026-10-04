import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

export 'package:url_launcher/url_launcher.dart' show LaunchMode;

/// Opens [uri] with [mode]. Callers always pass
/// `LaunchMode.externalApplication` (external browser, dialer, maps) —
/// never a WebView (TASK-12 §7.2). Returns false when nothing opened it.
typedef ExternalLauncher = Future<bool> Function(Uri uri, LaunchMode mode);

Future<bool> _launch(Uri uri, LaunchMode mode) async {
  try {
    return await launchUrl(uri, mode: mode);
  } catch (_) {
    return false;
  }
}

/// Overridden in tests with a recorder.
final externalLauncherProvider = Provider<ExternalLauncher>((ref) => _launch);
