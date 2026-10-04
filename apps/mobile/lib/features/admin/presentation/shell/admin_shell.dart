import 'package:flutter/material.dart';

import '../../../../core/theme/icons.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../admin_l10n.dart';
import '../../application/admin_complaints.dart';
import '../../data/models/complaint_summary.dart';
import '../widgets/admin_tokens.dart';
import 'admin_session_guard.dart';

/// Admin tab shell: Due, All, Rates, More (02 §3.3).
class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = adminL10n(context);
    final tokens = AdminTokens.of(context);
    final dueCount = ref.watch(dueCountProvider).value;
    final showBadge = dueCount != null && dueCount > 0;
    Widget dueIcon(IconData icon) => Semantics(
      label: showBadge ? l10n.adminDueBadgeSemantics(dueCount) : null,
      child: Badge(
        isLabelVisible: showBadge,
        backgroundColor: tokens.attention,
        textColor: tokens.text,
        label: Text(showBadge ? '$dueCount' : ''),
        child: Icon(icon),
      ),
    );
    return AdminSessionGuard(
      child: Scaffold(
        body: navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (index) {
            // Lists refresh when their tab regains focus (02 §5.4).
            switch (index) {
              case 0:
                ref.invalidate(dueCountProvider);
                ref.invalidate(
                  adminComplaintsProvider(ComplaintFilter.dueOnly),
                );
              case 1:
                ref.invalidate(adminComplaintsProvider);
              case 2:
                ref.invalidate(ratesProvider);
            }
            navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            );
          },
          destinations: <NavigationDestination>[
            NavigationDestination(
              key: const Key('adminTabDue'),
              icon: dueIcon(SaartheeIcons.notifications),
              selectedIcon: dueIcon(SaartheeIcons.notifications),
              label: l10n.adminTabDue,
            ),
            NavigationDestination(
              key: const Key('adminTabAll'),
              icon: const Icon(SaartheeIcons.listAlt),
              selectedIcon: const Icon(SaartheeIcons.listAlt),
              label: l10n.adminTabAll,
            ),
            NavigationDestination(
              key: const Key('adminTabRates'),
              icon: const Icon(SaartheeIcons.insights),
              selectedIcon: const Icon(SaartheeIcons.insights),
              label: l10n.adminTabRates,
            ),
            NavigationDestination(
              key: const Key('adminTabMore'),
              icon: const Icon(SaartheeIcons.more),
              selectedIcon: const Icon(SaartheeIcons.more),
              label: l10n.adminTabMore,
            ),
          ],
        ),
      ),
    );
  }
}
