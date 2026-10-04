import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/motion/haptics.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/widgets.dart';
import '../../application/initiatives_providers.dart';
import '../../application/rsvp_sign_in.dart';
import '../../data/initiative_models.dart';
import 'rsvp_button.dart';

/// Attendee count ("{n} of {cap} going", the number rolls) + [RsvpButton] +
/// "Cancel RSVP" (fades in over `short`) + reminder footer. Signs in first
/// when needed; morphs only after the server confirms.
class RsvpPanel extends ConsumerStatefulWidget {
  const RsvpPanel({super.key, required this.initiative});

  final Initiative initiative;

  @override
  ConsumerState<RsvpPanel> createState() => _RsvpPanelState();
}

class _RsvpPanelState extends ConsumerState<RsvpPanel> {
  bool _busy = false;

  InitiativeDetailController get _controller =>
      ref.read(initiativeDetailProvider(widget.initiative.id).notifier);

  void _announce(String message) {
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    );
  }

  void _report(AppLocalizations l10n, RsvpOutcome outcome) {
    final message = switch (outcome) {
      RsvpOutcome.ok => null,
      RsvpOutcome.full => l10n.initiativesFull,
      RsvpOutcome.notOpen => l10n.initiativesNotOpen,
      RsvpOutcome.started => l10n.initiativesStarted,
      RsvpOutcome.failed => l10n.initiativesRsvpError,
    };
    if (message != null && mounted) {
      showSaartheeToast(context, message, kind: ToastKind.error);
    }
  }

  Future<void> _rsvp() async {
    final l10n = AppLocalizations.of(context);
    if (!await ref.read(rsvpSignInProvider)(context, ref)) return;
    if (!mounted) return;
    setState(() => _busy = true);
    final outcome = await _controller.rsvp();
    if (!mounted) return;
    setState(() => _busy = false);
    if (outcome == RsvpOutcome.ok) {
      ref.read(saartheeHapticsProvider).light();
      _announce(l10n.initiativesYoureGoing);
    } else {
      _report(l10n, outcome);
    }
  }

  Future<void> _cancel() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    final outcome = await _controller.cancel();
    if (!mounted) return;
    setState(() => _busy = false);
    if (outcome == RsvpOutcome.ok) {
      _announce(l10n.initiativesRsvpCancelled);
    } else {
      _report(l10n, outcome);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = SaartheeMotion.of(context);
    final i = widget.initiative;
    final going = i.isGoing;
    final open =
        !i.isCancelled &&
        i.status == 'published' &&
        !i.hasStarted(DateTime.now());
    final count = Semantics(
      key: const Key('rsvp.count'),
      label: i.capacity == null
          ? l10n.initiativesGoing(i.goingCount)
          : l10n.initiativesCapacityLabel(i.goingCount, i.capacity!),
      excludeSemantics: true,
      child: Row(
        children: [
          RollingCount(
            key: const Key('rsvp.countValue'),
            value: i.goingCount,
            style: text.titleLarge?.copyWith(color: c.textPrimary),
          ),
          const SizedBox(width: AppSpacing.s4),
          Text(
            i.capacity == null
                ? l10n.initiativesGoingSuffix
                : l10n.initiativesOfCapacity(i.capacity!),
            style: text.bodyMedium,
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        count,
        if (open || going) ...[
          const SizedBox(height: AppSpacing.s16),
          RsvpButton(
            going: going,
            busy: _busy && !going,
            full: i.isFull(),
            onPressed: open ? _rsvp : null,
          ),
          AnimatedSwitcher(
            duration: scheme.short.duration,
            child: going && open
                ? Column(
                    key: const ValueKey('going'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: AppSpacing.s8),
                      TertiaryButton(
                        key: const Key('rsvp.cancel'),
                        label: l10n.initiativesCancelRsvp,
                        onPressed: _busy ? null : _cancel,
                      ),
                      Text(
                        l10n.initiativesRemindFooter,
                        textAlign: TextAlign.center,
                        style: text.bodySmall?.copyWith(color: c.textSecondary),
                      ),
                    ],
                  )
                : const SizedBox.shrink(key: ValueKey('not-going')),
          ),
        ],
      ],
    );
  }
}
