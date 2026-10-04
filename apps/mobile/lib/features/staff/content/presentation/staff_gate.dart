import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/motion/staff_motion_scope.dart';
import '../../../../core/theme/icons.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/application/session_controller.dart';

/// Role of the signed-in account ('' when signed out).
final staffRoleProvider = Provider<String>(
  (ref) => ref.watch(sessionProvider.select((s) => s.me?.role ?? '')),
);

/// Standalone role-guarded staff page (TASK-12 §5.4) until TASK-10's console
/// shell hosts it: app bar, `StaffMotionScope` (short fades only), content
/// width for wide screens, and "You don't have access to this page." for
/// other roles. The server enforces the same roles.
class StaffPage extends ConsumerWidget {
  const StaffPage({
    super.key,
    required this.title,
    required this.roles,
    required this.child,
    this.actions = const [],
    this.floatingActionButton,
  });

  final String title;
  final Set<String> roles;
  final Widget child;
  final List<Widget> actions;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final allowed = roles.contains(ref.watch(staffRoleProvider));
    return StaffMotionScope(
      child: Scaffold(
        // The console header (StaffShell) holds the language toggle.
        appBar: SaartheeAppBar(
          title: title,
          actions: allowed ? actions : const [],
          showLanguageToggle: false,
        ),
        floatingActionButton: allowed ? floatingActionButton : null,
        floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,
        body: allowed
            ? Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppSpacing.staffMaxContent,
                  ),
                  child: child,
                ),
              )
            : EmptyState(
                key: const Key('staff.forbidden'),
                icon: SaartheeIcons.lock,
                message: l10n.staffContentForbidden,
              ),
      ),
    );
  }
}

/// Leaves a saved form: back to the list it came from, or [fallback] when it
/// was opened directly.
void leaveForm(BuildContext context, String fallback) {
  final router = GoRouter.of(context);
  if (router.canPop()) {
    router.pop();
  } else {
    router.go(fallback);
  }
}

/// A JSON value as display text ('' for null).
String str(Object? v) => v == null ? '' : '$v';

const adminOnly = {'admin'};
const adminOrModerator = {'admin', 'moderator'};
