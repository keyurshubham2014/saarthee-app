import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/motion/staff_motion_scope.dart';
import '../../../core/theme/icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/application/session_controller.dart';
import '../shell/staff_session.dart';

/// Staff navigation registry contract (TASK-08 §6 step 16; TASK-10 renders
/// the side navigation). Feature tasks append items; append-only.
class StaffNavItem {
  const StaffNavItem({
    required this.route,
    required this.labelKey,
    required this.icon,
    required this.roles,
    this.section = StaffNavSection.work,
    this.emailSession = false,
  });

  final String route;

  /// ARB key of the label (resolved by TASK-10's shell, `staffNavLabel`).
  final String labelKey;
  final IconData icon;
  final Set<String> roles;

  /// TASK-10: side-navigation section label.
  final StaffNavSection section;

  /// TASK-10: the screen also works with the v1 email admin sign-in (its API
  /// accepts the v1 admin token); other items need a phone sign-in.
  final bool emailSession;
}

/// TASK-10 side-navigation sections, in display order.
enum StaffNavSection { work, content, admin }

final List<StaffNavItem> staffNavItems = <StaffNavItem>[
  // TASK-08 alerts.
  const StaffNavItem(
    route: '/staff/alerts',
    labelKey: 'staffAlertsTitle',
    icon: SaartheeIcons.navAlerts,
    roles: {'moderator', 'admin'},
    emailSession: true,
  ),
  // TASK-10 console sections (Dashboard and Moderation are listed before
  // Alerts by `staffNavFor`, which orders by section then this list).
  const StaffNavItem(
    route: '/staff',
    labelKey: 'staffNavDashboard',
    icon: SaartheeIcons.dashboard,
    roles: {'moderator', 'admin'},
    emailSession: true,
  ),
  const StaffNavItem(
    route: '/staff/moderation',
    labelKey: 'staffNavModeration',
    icon: SaartheeIcons.moderation,
    roles: {'moderator', 'admin'},
    emailSession: true,
  ),
  // TASK-12 services, initiatives and tips (mounted in the TASK-10 shell).
  const StaffNavItem(
    route: '/staff/services',
    labelKey: 'staffContentServicesTitle',
    icon: SaartheeIcons.services,
    roles: {'admin'},
    section: StaffNavSection.content,
  ),
  const StaffNavItem(
    route: '/staff/initiatives',
    labelKey: 'staffContentInitiativesTitle',
    icon: SaartheeIcons.event,
    roles: {'admin'},
    section: StaffNavSection.content,
  ),
  const StaffNavItem(
    route: '/staff/tips',
    labelKey: 'staffContentTipsTitle',
    icon: SaartheeIcons.catStreetlight,
    roles: {'admin'},
    section: StaffNavSection.content,
  ),
  // TASK-10 administration.
  const StaffNavItem(
    route: '/staff/categories',
    labelKey: 'staffNavCategories',
    icon: SaartheeIcons.category,
    roles: {'admin'},
    section: StaffNavSection.admin,
    emailSession: true,
  ),
  const StaffNavItem(
    route: '/staff/users',
    labelKey: 'staffNavUsers',
    icon: SaartheeIcons.group,
    roles: {'admin'},
    section: StaffNavSection.admin,
    emailSession: true,
  ),
  const StaffNavItem(
    route: '/staff/settings',
    labelKey: 'staffNavSettings',
    icon: SaartheeIcons.settings,
    roles: {'admin'},
    section: StaffNavSection.admin,
    emailSession: true,
  ),
  const StaffNavItem(
    route: '/staff/exports',
    labelKey: 'staffNavExports',
    icon: SaartheeIcons.download,
    roles: {'admin'},
    section: StaffNavSection.admin,
    emailSession: true,
  ),
  // TASK-11 representative console (phone sign-in) and claim review.
  const StaffNavItem(
    route: '/staff/ward',
    labelKey: 'wardDashNav',
    icon: SaartheeIcons.dashboard,
    roles: {'representative', 'moderator', 'admin'},
  ),
  const StaffNavItem(
    route: '/staff/ward/issues',
    labelKey: 'wardDashIssuesNav',
    icon: SaartheeIcons.listAlt,
    roles: {'representative', 'moderator', 'admin'},
  ),
  const StaffNavItem(
    route: '/staff/messages',
    labelKey: 'repMsgNav',
    icon: SaartheeIcons.message,
    roles: {'representative'},
  ),
  const StaffNavItem(
    route: '/staff/claims',
    labelKey: 'repClaimNav',
    icon: SaartheeIcons.badge,
    roles: {'moderator', 'admin'},
    section: StaffNavSection.admin,
  ),
];

/// TASK-10: the items a role sees, ordered by section (Dashboard and
/// Moderation first in "Work").
List<StaffNavItem> staffNavFor(String role, {bool emailSession = false}) {
  const first = ['/staff', '/staff/moderation'];
  final items = [
    for (final i in staffNavItems)
      if (i.roles.contains(role) && (!emailSession || i.emailSession)) i,
  ];
  int rank(StaffNavItem i) {
    final f = first.indexOf(i.route);
    return i.section.index * 100 + (f >= 0 ? f : 10 + staffNavItems.indexOf(i));
  }

  items.sort((a, b) => rank(a).compareTo(rank(b)));
  return items;
}

/// Current staff role from the session (`moderator`/`admin`), else null.
/// UX only — the API enforces roles.
final staffRoleProvider = Provider<String?>((ref) {
  final role = ref.watch(sessionProvider.select((s) => s.me?.role));
  if (role == 'moderator' || role == 'admin') return role;
  // TASK-10: the v1 email admin sign-in has no citizen session.
  if (ref.watch(staffEmailSessionProvider) == null) return null;
  final me = ref.watch(staffMeProvider).value;
  return me != null && (me.role == 'moderator' || me.role == 'admin')
      ? me.role
      : null;
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
        floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,
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
