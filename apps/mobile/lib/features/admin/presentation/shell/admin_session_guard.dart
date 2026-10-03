import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/admin_auth.dart';
import '../admin_paths.dart';

/// Wraps every signed-in admin screen. When the session ends (401
/// `TOKEN_EXPIRED`/`TOKEN_REVOKED`, local expiry on resume, or log out) it
/// sends the operator to `/admin/login`, returning to the current route
/// afterwards. Also unlocks rotation for admin screens (02 §2.2).
class AdminSessionGuard extends ConsumerStatefulWidget {
  const AdminSessionGuard({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<AdminSessionGuard> createState() => _AdminSessionGuardState();
}

class _AdminSessionGuardState extends ConsumerState<AdminSessionGuard> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.read(adminAuthProvider.notifier).checkExpiry(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(adminAuthProvider.notifier).checkExpiry();
      }
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AdminAuthState>(adminAuthProvider, (previous, next) {
      if (next.status != AdminAuthStatus.signedOut || !mounted) {
        return;
      }
      final router = GoRouter.of(context);
      if (next.sessionEnded) {
        final here = router.state.uri.toString();
        router.go(AdminPaths.loginReturningTo(here));
      } else {
        router.go(AdminPaths.login);
      }
    });
    return widget.child;
  }
}
