import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/motion/staff_motion_scope.dart';
import '../../../core/theme/icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/application/session_controller.dart';

/// Staff navigation registry contract (TASK-08 §6 step 16; TASK-10 renders
/// the side navigation). Feature tasks append items; append-only.
class StaffNavItem {
  const StaffNavItem({
    required this.route,
    required this.labelKey,
    required this.icon,
    required this.roles,
  });

  final String route;

  /// ARB key of the label (resolved by TASK-10's shell).
  final String labelKey;
  final IconData icon;
  final Set<String> roles;
}

final List<StaffNavItem> staffNavItems = <StaffNavItem>[
  // TASK-08 alerts.
  const StaffNavItem(
    route: '/staff/alerts',
    labelKey: 'staffAlertsTitle',
    icon: SaartheeIcons.navAlerts,
    roles: {'moderator', 'admin'},
  ),
];

/// Current staff role from the session (`moderator`/`admin`), else null.
/// UX only — the API enforces roles.
final staffRoleProvider = Provider<String?>((ref) {
  final role = ref.watch(sessionProvider.select((s) => s.me?.role));
  return role == 'moderator' || role == 'admin' ? role : null;
});

/// Minimal staff page until TASK-10's console shell exists: app bar, staff
/// motion (short fades only), a wide content column, and the 403 state for
/// non-staff sessions.
class StaffPageScaffold extends ConsumerWidget {
  const StaffPageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
    this.floatingActionButton,
  });

  final String title;
  final Widget body;
  final List<Widget> actions;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(staffRoleProvider);
    return StaffMotionScope(
      child: Scaffold(
        appBar: SaartheeAppBar(
          title: title,
          actions: actions,
          showLanguageToggle: false,
        ),
        floatingActionButton: role == null ? null : floatingActionButton,
        body: role == null
            ? EmptyState(
                message: AppLocalizations.of(context).staffAlertsNoAccess,
                icon: SaartheeIcons.lock,
              )
            : Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppSpacing.staffMaxContent,
                  ),
                  child: body,
                ),
              ),
      ),
    );
  }
}
