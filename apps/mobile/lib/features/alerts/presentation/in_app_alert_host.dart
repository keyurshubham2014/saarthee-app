import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/alerts/in_app_alert_banner.dart';
import '../application/in_app_alert_controller.dart';

/// Mounted by the citizen shell around the tab body: shows the in-app alert
/// banner directly under the current app bar, clipped to the area below it
/// (REQ-F-065). Tap → `/alerts/:id`.
class InAppAlertHost extends ConsumerWidget {
  const InAppAlertHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alert = ref.watch(inAppAlertProvider);
    final top = MediaQuery.paddingOf(context).top + kToolbarHeight;
    return Stack(
      children: [
        child,
        if (alert != null)
          Positioned(
            top: top,
            left: 0,
            right: 0,
            child: InAppAlertBanner(
              key: ValueKey('inAppAlert.${alert.id}'),
              severity: alert.severity,
              title: alert.title,
              onView: () {
                ref.read(inAppAlertProvider.notifier).clear(alert.id);
                GoRouter.of(context).go('/alerts/${alert.id}');
              },
              onDismissed: () =>
                  ref.read(inAppAlertProvider.notifier).clear(alert.id),
            ),
          ),
      ],
    );
  }
}
