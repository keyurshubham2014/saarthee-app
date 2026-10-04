import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/motion/staff_motion_scope.dart';
import '../../../core/theme/icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../shared/staff_shared.dart';
import 'staff_nav_labels.dart';
import 'staff_session.dart';

/// Wide layout breakpoint (DS §4): persistent side navigation from 840 dp.
const double staffWideBreakpoint = 840;
const double _navWidth = 264;

/// The registry item that owns [location] (longest matching route).
StaffNavItem? staffItemFor(String location) {
  StaffNavItem? best;
  for (final i in staffNavItems) {
    final match = i.route == '/staff'
        ? location == '/staff'
        : location == i.route || location.startsWith('${i.route}/');
    if (match && (best == null || i.route.length > best.route.length)) {
      best = i;
    }
  }
  return best;
}

/// TASK-10 staff console shell (web and in-app `/staff`): header with
/// "Saarthee staff", role chip and Sign out; side navigation ≥ 840 dp, menu
/// drawer below; role-aware items from the registry; `StaffMotionScope`.
class StaffShell extends ConsumerWidget {
  const StaffShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final me = ref.watch(staffMeProvider);
    return StaffMotionScope(
      child: me.when(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, _) {
          final access = e is StaffAccessException
              ? e.access
              : StaffAccess.error;
          return Scaffold(
            body: Center(
              child: access == StaffAccess.error
                  ? ErrorState(
                      message: l10n.staffLoadError,
                      onRetry: () => ref.invalidate(staffMeProvider),
                    )
                  : EmptyState(
                      key: const Key('staff.noAccess'),
                      icon: SaartheeIcons.lock,
                      message: access == StaffAccess.suspended
                          ? l10n.staffLoginSuspended
                          : l10n.staffLoginNotStaff,
                      actionLabel: l10n.staffSignOut,
                      onAction: () async {
                        await staffSignOut(ref);
                        if (context.mounted) context.go('/staff/login');
                      },
                    ),
            ),
          );
        },
        data: (staff) =>
            _Layout(location: location, staff: staff, child: child),
      ),
    );
  }
}

class _Layout extends ConsumerWidget {
  const _Layout({
    required this.location,
    required this.staff,
    required this.child,
  });

  final String location;
  final StaffMe staff;
  final Widget child;

  Widget _body(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final owner = staffItemFor(location);
    if (location == '/staff/forbidden' ||
        (owner != null && !owner.roles.contains(staff.role))) {
      return StaffForbiddenView(showDashboard: staff.role != 'representative');
    }
    if (staff.role == 'representative' && location == '/staff') {
      return EmptyState(
        icon: SaartheeIcons.badge,
        message: l10n.staffNoSections,
      );
    }
    return child;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = staffNavFor(
      staff.role,
      emailSession: staff.actorKind == 'admin_user',
    );
    final wide = MediaQuery.sizeOf(context).width >= staffWideBreakpoint;
    final nav = StaffSideNav(items: items, location: location);
    return Scaffold(
      appBar: StaffHeader(staff: staff, showMenu: !wide && items.isNotEmpty),
      drawer: wide || items.isEmpty
          ? null
          : Drawer(child: SafeArea(child: nav)),
      body: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (items.isNotEmpty) SizedBox(width: _navWidth, child: nav),
                if (items.isNotEmpty)
                  const VerticalDivider(width: AppSpacing.borderWidth),
                Expanded(child: _body(context)),
              ],
            )
          : _body(context),
    );
  }
}

/// Console header: brand title, role chip, Sign out (DS §9 Staff).
class StaffHeader extends ConsumerWidget implements PreferredSizeWidget {
  const StaffHeader({super.key, required this.staff, required this.showMenu});

  final StaffMe staff;
  final bool showMenu;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    final text = Theme.of(context).textTheme;
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: c.surface,
      leading: showMenu
          ? Builder(
              builder: (ctx) => IconButton(
                key: const Key('staff.menu'),
                tooltip: l10n.staffMenu,
                icon: const Icon(SaartheeIcons.menu),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            )
          : null,
      titleSpacing: showMenu ? 0 : AppSpacing.gutter,
      title: Row(
        children: [
          Flexible(
            child: Text(
              l10n.staffConsoleTitle,
              style: text.titleLarge,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          Container(
            key: const Key('staff.roleChip'),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s12,
              vertical: AppSpacing.s4,
            ),
            decoration: BoxDecoration(
              color: c.primaryContainer,
              borderRadius: BorderRadius.circular(AppSpacing.s40),
            ),
            child: Text(
              staffRoleLabel(l10n, staff.role),
              style: text.labelLarge?.copyWith(color: c.onPrimaryContainer),
            ),
          ),
        ],
      ),
      actions: [
        TextButton.icon(
          key: const Key('staff.signOut'),
          onPressed: () async {
            await staffSignOut(ref);
            if (context.mounted) context.go('/staff/login');
          },
          icon: const Icon(SaartheeIcons.logout),
          label: Text(l10n.staffSignOut),
        ),
        const SizedBox(width: AppSpacing.s8),
      ],
      shape: Border(bottom: BorderSide(color: c.border)),
    );
  }
}

/// Side navigation with section labels; the selected item has the
/// `primaryContainer` pill and a filled Rounded icon.
class StaffSideNav extends StatelessWidget {
  const StaffSideNav({super.key, required this.items, required this.location});

  final List<StaffNavItem> items;
  final String location;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    final text = Theme.of(context).textTheme;
    final selected = staffItemFor(location);
    final children = <Widget>[];
    StaffNavSection? section;
    for (final item in items) {
      if (item.section != section) {
        section = item.section;
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s24,
              AppSpacing.s20,
              AppSpacing.s16,
              AppSpacing.s8,
            ),
            child: Text(
              staffSectionLabel(l10n, item.section),
              style: text.labelMedium?.copyWith(color: c.textSecondary),
            ),
          ),
        );
      }
      final isSelected = identical(item, selected);
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s12,
            vertical: 2,
          ),
          child: Material(
            color: isSelected ? c.primaryContainer : c.surface,
            shape: const StadiumBorder(),
            child: InkWell(
              key: Key('staff.nav.${item.route}'),
              customBorder: const StadiumBorder(),
              onTap: () {
                Scaffold.maybeOf(context)?.closeDrawer();
                context.go(item.route);
              },
              child: Semantics(
                selected: isSelected,
                button: true,
                child: SizedBox(
                  height: AppSpacing.touchTarget,
                  child: Row(
                    children: [
                      const SizedBox(width: AppSpacing.s16),
                      Icon(
                        item.icon,
                        fill: isSelected ? 1 : 0,
                        color: isSelected
                            ? c.onPrimaryContainer
                            : c.textSecondary,
                      ),
                      const SizedBox(width: AppSpacing.s12),
                      Expanded(
                        child: Text(
                          staffNavLabel(l10n, item.labelKey),
                          style: text.bodyLarge?.copyWith(
                            color: isSelected
                                ? c.onPrimaryContainer
                                : c.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return ColoredBox(
      color: c.surface,
      child: ListView(children: children),
    );
  }
}

/// "You don't have access to this page." + "Go to dashboard".
class StaffForbiddenView extends StatelessWidget {
  const StaffForbiddenView({super.key, this.showDashboard = true});

  final bool showDashboard;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: EmptyState(
        key: const Key('staff.forbidden'),
        icon: SaartheeIcons.lock,
        message: l10n.staffForbidden,
        actionLabel: showDashboard ? l10n.staffGoDashboard : null,
        onAction: showDashboard ? () => context.go('/staff') : null,
      ),
    );
  }
}
