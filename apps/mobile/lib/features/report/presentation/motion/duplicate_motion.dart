import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/motion/motion_widgets.dart';
import '../../../../core/theme/icons.dart';
import '../../../../core/theme/tokens.dart';

/// "Already reported nearby" card entering from under the map: translate-Y
/// from −its height to 0 with `springIn`, clipped by the map's bottom edge
/// (DS §6). Reduced motion → shown at once.
class DuplicateCardSlide extends StatefulWidget {
  const DuplicateCardSlide({super.key, required this.child});

  final Widget child;

  @override
  State<DuplicateCardSlide> createState() => DuplicateCardSlideState();
}

class DuplicateCardSlideState extends State<DuplicateCardSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  bool _started = false;

  /// Fraction of the card height still hidden above (1 → 0), for tests.
  double get hiddenFraction =>
      1 - SaartheeMotion.spring.transform(_c.value).clamp(0.0, 1.2);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final spec = SaartheeMotion.of(context).springIn;
    if (spec.isInstant) {
      _c.value = 1;
      return;
    }
    _c.duration = spec.duration;
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRect(
    child: AnimatedBuilder(
      animation: _c,
      builder: (context, child) => FractionalTranslation(
        translation: Offset(0, -hiddenFraction),
        child: child,
      ),
      child: widget.child,
    ),
  );
}

enum MeTooPhase { idle, sending, added }

/// "Add me too" → in-button progress → "Added ✓" (label cross-fade `short`,
/// `MotionCheck` in place of the icon, fixed width). [onPressed] records the
/// me-too and returns true on success; [onAdded] runs once the check has
/// finished drawing (next frame with reduced motion). Light haptic on press.
class MeTooButton extends ConsumerStatefulWidget {
  const MeTooButton({
    super.key,
    required this.onPressed,
    required this.onAdded,
  });

  final Future<bool> Function() onPressed;
  final VoidCallback onAdded;

  @override
  ConsumerState<MeTooButton> createState() => MeTooButtonState();
}

class MeTooButtonState extends ConsumerState<MeTooButton> {
  MeTooPhase phase = MeTooPhase.idle;
  Timer? _done;

  @override
  void dispose() {
    _done?.cancel();
    super.dispose();
  }

  Future<void> _press() async {
    if (phase != MeTooPhase.idle) return;
    unawaited(ref.read(saartheeHapticsProvider).light());
    setState(() => phase = MeTooPhase.sending);
    final ok = await widget.onPressed();
    if (!mounted) return;
    if (!ok) {
      setState(() => phase = MeTooPhase.idle);
      return;
    }
    setState(() => phase = MeTooPhase.added);
    final scheme = SaartheeMotion.of(context);
    if (scheme.isReduced) {
      // Confirmation on the next frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onAdded();
      });
      return;
    }
    final wait =
        scheme.short.duration +
        scheme.drawCheckDelay +
        scheme.drawCheck.duration;
    _done = Timer(wait, widget.onAdded);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    final short = SaartheeMotion.of(context).short;
    final Widget content = switch (phase) {
      MeTooPhase.sending => SizedBox.square(
        key: const ValueKey('meToo.progress'),
        dimension: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: c.onPrimary),
      ),
      MeTooPhase.added => Row(
        key: const ValueKey('meToo.added'),
        mainAxisSize: MainAxisSize.min,
        children: [
          MotionCheck(
            color: c.onPrimary,
            semanticLabel: l10n.reportDupAdded,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.s8),
          Text(l10n.reportDupAdded),
        ],
      ),
      MeTooPhase.idle => Row(
        key: const ValueKey('meToo.idle'),
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(SaartheeIcons.thumbUp, size: 20),
          const SizedBox(width: AppSpacing.s8),
          Text(l10n.reportDupAddMeToo),
        ],
      ),
    };
    return SizedBox(
      width: double.infinity,
      height: AppSpacing.buttonHeight,
      child: FilledButton(
        key: const Key('report.dup.addMeToo'),
        onPressed: phase == MeTooPhase.idle ? _press : () {},
        child: AnimatedSwitcher(
          duration: short.duration,
          switchInCurve: short.curve,
          switchOutCurve: short.curve,
          child: content,
        ),
      ),
    );
  }
}
