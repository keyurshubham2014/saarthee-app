import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../l10n/app_localizations.dart';
import '../motion/haptics.dart';
import '../motion/motion_check.dart';
import '../theme/icons.dart';
import '../theme/motion.dart';
import '../theme/tokens.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ToastKind { success, info, error }

/// The toast body (DS §5): `primaryDark`, white text, radius 18,
/// elevation 3, leading drawn check (success) or Rounded icon.
class SaartheeToast extends StatelessWidget {
  const SaartheeToast({
    super.key,
    required this.message,
    this.kind = ToastKind.success,
    this.checkProgress,
  });

  final String message;
  final ToastKind kind;

  /// Pins the check drawing (goldens).
  final double? checkProgress;

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final l10n = AppLocalizations.of(context);
    final fg = c.onToast;
    return Material(
      key: const Key('toast'),
      color: c.primaryDark,
      elevation: AppElevation.overlay,
      shadowColor: c.shadow,
      borderRadius: AppRadii.cardRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s14,
        ),
        child: Row(
          children: [
            switch (kind) {
              ToastKind.success => MotionCheck(
                color: fg,
                semanticLabel: l10n.componentDone,
                progress: checkProgress,
              ),
              ToastKind.info => Icon(SaartheeIcons.info, color: fg),
              ToastKind.error => Icon(SaartheeIcons.error, color: fg),
            },
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

OverlayEntry? _current;

/// Shows a toast above the bottom navigation: slides up with `springIn`,
/// holds for `SaartheeMotion.toastHold` (4 s), is announced to screen
/// readers, and gives a success haptic for [ToastKind.success].
void showSaartheeToast(
  BuildContext context,
  String message, {
  ToastKind kind = ToastKind.success,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  _current?.remove();
  _current = null;
  if (kind == ToastKind.success) {
    ProviderScope.containerOf(
      context,
      listen: false,
    ).read(saartheeHapticsProvider).success();
  }
  final view = View.of(context);
  SemanticsService.sendAnnouncement(view, message, Directionality.of(context));
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _ToastHost(
      message: message,
      kind: kind,
      onDone: () {
        if (_current == entry) _current = null;
        if (entry.mounted) entry.remove();
      },
    ),
  );
  _current = entry;
  overlay.insert(entry);
}

class _ToastHost extends StatefulWidget {
  const _ToastHost({
    required this.message,
    required this.kind,
    required this.onDone,
  });

  final String message;
  final ToastKind kind;
  final VoidCallback onDone;

  @override
  State<_ToastHost> createState() => _ToastHostState();
}

class _ToastHostState extends State<_ToastHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  Timer? _timer;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final scheme = SaartheeMotion.of(context);
    final inSpec = scheme.springIn.isInstant ? scheme.medium : scheme.springIn;
    _c.duration = inSpec.duration;
    _c.reverseDuration = scheme.medium.duration;
    _c.forward();
    _timer = Timer(SaartheeMotion.toastHold, () async {
      if (!mounted) return;
      await _c.reverse();
      widget.onDone();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = SaartheeMotion.of(context);
    final curve = scheme.transforms ? SaartheeMotion.spring : Curves.linear;
    final bottom = MediaQuery.paddingOf(context).bottom + 88;
    return Positioned(
      left: AppSpacing.gutter,
      right: AppSpacing.gutter,
      bottom: bottom,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final t = curve.transform(_c.value);
          return Opacity(
            opacity: _c.value.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, scheme.transforms ? (1 - t) * 24 : 0),
              child: child,
            ),
          );
        },
        child: SafeArea(
          top: false,
          child: SaartheeToast(message: widget.message, kind: widget.kind),
        ),
      ),
    );
  }
}
