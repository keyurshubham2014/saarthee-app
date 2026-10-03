import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/analytics/event_queue.dart';
import '../core/config/app_config.dart';
import '../features/verify/application/verify_token.dart';
import 'app_router.dart';

/// Listens for `saarthee://verify?t=<token>` (02 §3.1). The token goes
/// straight into memory (`verifyTokenProvider`) and the router opens
/// `/verify` WITHOUT the token in its location, so it is never logged,
/// persisted or forwarded in a URL.
class DeepLinkListener {
  DeepLinkListener(this._ref) {
    final links = AppLinks();
    links.getInitialLink().then((uri) {
      if (uri != null) _handle(uri);
    });
    _sub = links.uriLinkStream.listen(_handle, onError: (Object _) {});
  }

  final Ref _ref;
  StreamSubscription<Uri>? _sub;

  void _handle(Uri uri) {
    final isVerify =
        (uri.scheme == AppConfig.deepLinkScheme && uri.host == 'verify') ||
        uri.path == '/verify';
    if (!isVerify) return;
    final token = extractVerifyToken(uri.toString());
    final router = _ref.read(appRouterProvider);
    if (token == null) {
      _ref.read(eventQueueProvider).track(AppEvents.deepLinkFailed, {
        'reason': 'parse',
      });
      router.go('/verify/enter-code');
      return;
    }
    _ref.read(verifyTokenProvider.notifier).set(token);
    router.go('/verify');
  }

  void dispose() => _sub?.cancel();
}

final deepLinkListenerProvider = Provider<DeepLinkListener>((ref) {
  final l = DeepLinkListener(ref);
  ref.onDispose(l.dispose);
  return l;
});
