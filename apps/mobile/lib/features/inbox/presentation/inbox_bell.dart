import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/icons.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/rolling_count.dart';
import '../application/inbox_controller.dart';

/// App-bar bell (DS §5) with the unread badge: the count rolls to its new
/// value (`RollingCount`, `short`) and the badge fades out at 0; "9+" above 9.
class InboxBell extends ConsumerWidget {
  const InboxBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    final count = ref.watch(inboxUnreadCountProvider);
    final motion = SaartheeMotion.of(context);
    final style = Theme.of(context).textTheme.labelSmall
        ?.copyWith(color: c.onPrimary);
    return Semantics(
      button: true,
      label: count > 0 ? l10n.inboxBellLabel(count) : l10n.inboxTitle,
      excludeSemantics: true,
      child: IconButton(
        key: const ValueKey('inboxBell'),
        onPressed: () => GoRouter.of(context).push('/me/notifications'),
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(SaartheeIcons.notifications),
            PositionedDirectional(
              top: -AppSpacing.s4,
              end: -AppSpacing.s8,
              child: AnimatedOpacity(
                key: const ValueKey('inboxBadge'),
                opacity: count > 0 ? 1 : 0,
                duration: motion.short.duration,
                curve: motion.short.curve,
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: c.primary,
                    shape: const StadiumBorder(),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s4,
                    ),
                    child: count > 9
                        ? Text('9+', style: style)
                        : RollingCount(value: count, style: style),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
