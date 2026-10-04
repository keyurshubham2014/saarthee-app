import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/chips.dart';

/// The status word shown and announced (DS §2), incl. "Fixed (not verified)".
String lifecycleStatusWord(
  AppLocalizations l10n,
  IssueStatus status, {
  bool fixedUnverified = false,
}) => fixedUnverified && status == IssueStatus.markedFixed
    ? l10n.issueActionsStatusFixedUnverified
    : issueStatusLabel(l10n, status);

/// Status chip that cross-fades tint, text colour, icon and word together
/// over `short` when the status changes on screen (DS §6, REQ-F-063), and
/// announces "Status changed to `word`" once per change. First build: no
/// animation, no announcement. Reduced motion: instant swap, still announced.
class AnimatedStatusChip extends StatefulWidget {
  const AnimatedStatusChip({
    super.key,
    required this.status,
    this.fixedUnverified = false,
  });

  final IssueStatus status;
  final bool fixedUnverified;

  @override
  State<AnimatedStatusChip> createState() => _AnimatedStatusChipState();
}

class _AnimatedStatusChipState extends State<AnimatedStatusChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    value: 1,
  );
  IssueStatus? _previous;
  bool _previousUnverified = false;

  @override
  void didUpdateWidget(AnimatedStatusChip old) {
    super.didUpdateWidget(old);
    final changed =
        old.status != widget.status ||
        old.fixedUnverified != widget.fixedUnverified;
    if (!changed) return;
    _previous = old.status;
    _previousUnverified = old.fixedUnverified;
    final spec = SaartheeMotion.of(context).short;
    if (spec.isInstant) {
      _c.value = 1;
    } else {
      _c.duration = spec.duration;
      _c.forward(from: 0);
    }
    _announce();
  }

  void _announce() {
    final l10n = AppLocalizations.of(context);
    final word = lifecycleStatusWord(
      l10n,
      widget.status,
      fixedUnverified: widget.fixedUnverified,
    );
    SemanticsService.sendAnnouncement(
      View.of(context),
      l10n.issueActionsStatusAnnounce(word),
      Directionality.of(context),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _chip(BuildContext context, IssueStatus s, bool unverified) {
    if (unverified && s == IssueStatus.markedFixed) {
      return ToneChip(
        key: const ValueKey('statusChip.fixedUnverified'),
        tone: IssueStatusStyle.of(s),
        label: AppLocalizations.of(context).issueActionsStatusFixedUnverified,
      );
    }
    return StatusChip(status: s);
  }

  @override
  Widget build(BuildContext context) {
    final current = _chip(context, widget.status, widget.fixedUnverified);
    final previous = _previous;
    if (previous == null) return current;
    final curve = SaartheeMotion.short.curve;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        if (_c.isCompleted) return current;
        final t = curve.transform(_c.value);
        return Stack(
          alignment: AlignmentDirectional.centerStart,
          children: [
            Opacity(
              opacity: 1 - t,
              child: ExcludeSemantics(
                child: _chip(context, previous, _previousUnverified),
              ),
            ),
            Opacity(opacity: t, child: current),
          ],
        );
      },
    );
  }
}
