import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/widgets.dart';
import '../alerts/presentation/in_app_alert_host.dart';

/// The five-tab citizen shell (DS §5): body from the branch navigators,
/// bottom [SaartheeNavigationBar]. Re-tapping the current tab returns that
/// branch to its root.
class ShellScaffold extends StatelessWidget {
  const ShellScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // TASK-08: in-app alert banner under the current app bar.
      body: InAppAlertHost(child: navigationShell),
      bottomNavigationBar: SaartheeNavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onSelected: (i) => navigationShell.goBranch(
          i,
          initialLocation: i == navigationShell.currentIndex,
        ),
      ),
    );
  }
}
