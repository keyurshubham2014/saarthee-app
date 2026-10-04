import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/motion/haptics.dart';
import '../../../../core/theme/icons.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/rolling_count.dart';
import '../../../auth/application/ensure_signed_in.dart';
import '../../application/social_controller.dart';

void _failed(BuildContext context) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).discoveryActionFailed),
      ),
    );
}

/// "Me too" (DS §6): the icon springs 1 → 1.2 → 1 (`springIn`), the count
/// rolls (`RollingCount`, `short`) and a light haptic fires. Optimistic;
/// on failure the count rolls back and a snackbar explains. Signed out →
/// sign-in first, then the action runs.
class MeTooButton extends ConsumerStatefulWidget {
  const MeTooButton({super.key, required this.issueId, this.enabled = true});

  final String issueId;
  final bool enabled;

  /// Peak scale of the icon spring.
  static const double peakScale = 1.2;

  @override
  ConsumerState<MeTooButton> createState() => _MeTooButtonState();
}

class _MeTooButtonState extends ConsumerState<MeTooButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);

  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 1, end: MeTooButton.peakScale),
      weight: 1,
    ),
    TweenSequenceItem(
      tween: Tween(begin: MeTooButton.peakScale, end: 1),
      weight: 1,
    ),
  ]).animate(_c);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _tap() async {
    // The intent is fixed at the tap: after a sign-in the refreshed state may
    // already show it (e.g. the reporter), and a toggle would undo it.
    final turningOn = !ref.read(socialProvider(widget.issueId)).hasMeToo;
    if (!await ensureSignedIn(context, ref, reason: SignInReason.meToo)) {
      return;
    }
    if (!mounted) return;
    ref.read(saartheeHapticsProvider).light();
    final spec = SaartheeMotion.of(context).springIn;
    if (turningOn &&
        !ref.read(socialProvider(widget.issueId)).hasMeToo &&
        !spec.isInstant) {
      _c.duration = spec.duration;
      _c.forward(from: 0);
    }
    final ok = await ref
        .read(socialProvider(widget.issueId).notifier)
        .setMeToo(turningOn);
    if (!ok && mounted) _failed(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    final s = ref.watch(socialProvider(widget.issueId));
    final fg = s.hasMeToo ? c.primary : c.textPrimary;
    return Semantics(
      button: true,
      toggled: s.hasMeToo,
      label: l10n.discoveryMeTooSemantics(s.meTooCount),
      excludeSemantics: true,
      child: OutlinedButton(
        key: const Key('detail.meToo'),
        onPressed: widget.enabled ? _tap : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: fg,
          minimumSize: const Size(48, 48),
          side: BorderSide(color: s.hasMeToo ? c.primary : c.border),
          backgroundColor: s.hasMeToo ? c.primaryContainer : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              key: const Key('detail.meToo.icon'),
              scale: _scale,
              child: Icon(
                SaartheeIcons.thumbUp,
                fill: s.hasMeToo ? SaartheeIcons.fillOn : 0,
                size: AppSpacing.iconSmall,
                color: fg,
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            Text(l10n.discoveryMeToo),
            const SizedBox(width: AppSpacing.s4),
            RollingCount(
              key: const Key('detail.meToo.count'),
              value: s.meTooCount,
            ),
          ],
        ),
      ),
    );
  }
}

/// Follow / Following toggle (optimistic, rollback with a snackbar).
class FollowButton extends ConsumerWidget {
  const FollowButton({super.key, required this.issueId, this.enabled = true});

  final String issueId;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    final on = ref.watch(socialProvider(issueId).select((s) => s.isFollowing));
    return Semantics(
      button: true,
      toggled: on,
      label: on ? l10n.discoveryFollowing : l10n.discoveryFollow,
      excludeSemantics: true,
      child: OutlinedButton.icon(
        key: const Key('detail.follow'),
        onPressed: !enabled
            ? null
            : () async {
                final want = !on; // intent fixed at the tap (see Me too)
                if (!await ensureSignedIn(
                  context,
                  ref,
                  reason: SignInReason.follow,
                )) {
                  return;
                }
                final ok = await ref
                    .read(socialProvider(issueId).notifier)
                    .setFollow(want);
                if (!ok && context.mounted) _failed(context);
              },
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: on ? c.primary : c.textPrimary,
        ),
        icon: Icon(
          on ? SaartheeIcons.check : SaartheeIcons.add,
          size: AppSpacing.iconSmall,
        ),
        label: Text(on ? l10n.discoveryFollowing : l10n.discoveryFollow),
      ),
    );
  }
}
