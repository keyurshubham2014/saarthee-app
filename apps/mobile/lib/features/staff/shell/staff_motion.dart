import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens.dart';

/// DS §6 staff console motion (REQ-F-048): every staff route, dialog, sheet
/// and toast is a cross-fade lasting `SaartheeMotion.short`; with reduced
/// motion it is instant. No slides, scales, staggers, springs or count-ups.
Duration staffFade(BuildContext context) {
  final scheme = SaartheeMotion.of(context);
  return scheme.isReduced ? Duration.zero : SaartheeMotion.short.duration;
}

/// go_router page for staff routes: `short` fade only (independent of where
/// the router's context sits relative to `StaffMotionScope`).
Page<T> staffPage<T>(BuildContext context, GoRouterState state, Widget child) {
  final duration = staffFade(context);
  return CustomTransitionPage<T>(
    key: state.pageKey,
    name: state.name,
    arguments: state.extra,
    child: child,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    transitionsBuilder: (_, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

/// A staff `GoRoute` (fade page).
GoRoute staffRoute({
  required String path,
  required Widget Function(BuildContext context, GoRouterState state) builder,
  GoRouterRedirect? redirect,
}) => GoRoute(
  path: path,
  redirect: redirect,
  pageBuilder: (context, state) =>
      staffPage<void>(context, state, builder(context, state)),
);

/// Confirm / form dialog with a `short` fade (no scale).
Future<T?> showStaffDialog<T>(
  BuildContext context,
  WidgetBuilder builder,
) {
  final duration = staffFade(context);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: NeemFixed.scrim,
    transitionDuration: duration,
    pageBuilder: (ctx, _, _) => builder(ctx),
    transitionBuilder: (_, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

OverlayEntry? _toast;

/// Staff toast: fades in and out over `short`, holds `toastHold`, announced
/// to screen readers. No slide, spring or haptics (web).
void showStaffToast(BuildContext context, String message, {bool error = false}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  final duration = staffFade(context);
  _toast?.remove();
  SemanticsService.sendAnnouncement(
    View.of(context),
    message,
    Directionality.of(context),
  );
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _StaffToast(
      message: message,
      error: error,
      duration: duration,
      onDone: () {
        if (_toast == entry) _toast = null;
        entry.remove();
      },
    ),
  );
  _toast = entry;
  overlay.insert(entry);
}

class _StaffToast extends StatefulWidget {
  const _StaffToast({
    required this.message,
    required this.error,
    required this.duration,
    required this.onDone,
  });

  final String message;
  final bool error;
  final Duration duration;
  final VoidCallback onDone;

  @override
  State<_StaffToast> createState() => _StaffToastState();
}

class _StaffToastState extends State<_StaffToast> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });
    Future<void>.delayed(SaartheeMotion.toastHold, () {
      if (!mounted) return;
      setState(() => _visible = false);
      Future<void>.delayed(widget.duration, widget.onDone);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    return Positioned(
      left: AppSpacing.gutter,
      right: AppSpacing.gutter,
      bottom: AppSpacing.s24,
      child: IgnorePointer(
        child: AnimatedOpacity(
          key: const Key('staff.toast'),
          opacity: _visible ? 1 : 0,
          duration: widget.duration,
          child: Center(
            child: Material(
              color: widget.error ? c.error : c.primaryDark,
              borderRadius: AppRadii.controlRadius,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s16,
                  vertical: AppSpacing.s12,
                ),
                child: Text(
                  widget.message,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: c.onToast),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
