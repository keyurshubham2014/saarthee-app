import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/motion.dart';
import '../theme/tokens.dart';

/// go_router page with the DS §6 push motion: shared-axis X over `medium`
/// (back reverses). Reduced motion → 100 ms cross-fade; inside
/// `StaffMotionScope` → `short` fade only.
Page<T> saartheePage<T>({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) {
  final scheme = SaartheeMotion.of(context);
  final spec = scheme.medium;
  return CustomTransitionPage<T>(
    key: state.pageKey,
    name: state.name,
    arguments: state.extra,
    child: child,
    transitionDuration: spec.duration,
    reverseTransitionDuration: spec.duration,
    transitionsBuilder: (context, animation, secondary, child) =>
        SaartheeTransitions.page(
          scheme: scheme,
          animation: animation,
          secondaryAnimation: secondary,
          fillColor: SaartheeColors.of(context).background,
          child: child,
        ),
  );
}

/// Shared transition builders (DS §6 catalogue: push, tab, sheet).
class SaartheeTransitions {
  const SaartheeTransitions._();

  /// Push / pop between pages.
  static Widget page({
    required SaartheeMotionScheme scheme,
    required Animation<double> animation,
    required Animation<double> secondaryAnimation,
    required Color fillColor,
    required Widget child,
  }) {
    if (!scheme.transforms) {
      return FadeTransition(opacity: animation, child: child);
    }
    return SharedAxisTransition(
      animation: CurvedAnimation(
        parent: animation,
        curve: SaartheeMotion.standard,
      ),
      secondaryAnimation: CurvedAnimation(
        parent: secondaryAnimation,
        curve: SaartheeMotion.standard,
      ),
      transitionType: SharedAxisTransitionType.horizontal,
      fillColor: fillColor,
      child: child,
    );
  }
}

/// Shell body that keeps every tab branch alive (each keeps its scroll and
/// pushed pages) and fades through (`medium`) when the tab changes: the old
/// tab fades out over the first 35%, the new one fades in and scales from
/// 0.92 over the rest. Reduced motion → 100 ms cross-fade, no scale.
class FadeThroughShellContainer extends StatefulWidget {
  const FadeThroughShellContainer({
    super.key,
    required this.currentIndex,
    required this.children,
  });

  final int currentIndex;
  final List<Widget> children;

  @override
  State<FadeThroughShellContainer> createState() =>
      _FadeThroughShellContainerState();
}

class _FadeThroughShellContainerState extends State<FadeThroughShellContainer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    value: 1,
  );
  int? _previous;

  @override
  void didUpdateWidget(FadeThroughShellContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _previous = oldWidget.currentIndex;
      final spec = SaartheeMotion.of(context).medium;
      _controller.duration = spec.duration;
      _controller.forward(from: 0).whenCompleteOrCancel(() {
        if (mounted) setState(() => _previous = null);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = SaartheeMotion.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          _branch(i, scheme, widget.children[i]),
      ],
    );
  }

  Widget _branch(int i, SaartheeMotionScheme scheme, Widget child) {
    final isCurrent = i == widget.currentIndex;
    final isOutgoing = i == _previous && _controller.isAnimating;
    final visible = isCurrent || isOutgoing;
    return Offstage(
      key: ValueKey('shell-branch-$i'),
      offstage: !visible,
      child: TickerMode(
        enabled: visible,
        child: IgnorePointer(
          ignoring: !isCurrent,
          child: ExcludeSemantics(
            excluding: !isCurrent,
            child: AnimatedBuilder(
              animation: _controller,
              child: child,
              builder: (context, child) {
                final t = _controller.value;
                double opacity;
                var scale = 1.0;
                if (!scheme.transforms) {
                  opacity = isCurrent ? t : 1 - t;
                } else if (isCurrent) {
                  final p = ((t - 0.35) / 0.65).clamp(0.0, 1.0);
                  final eased = SaartheeMotion.standard.transform(p);
                  opacity = eased;
                  scale = 0.92 + 0.08 * eased;
                } else {
                  opacity = 1 - (t / 0.35).clamp(0.0, 1.0);
                }
                // Same widget structure in every frame so branch state is
                // never re-parented.
                return Opacity(
                  opacity: opacity,
                  child: Transform.scale(scale: scale, child: child),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet that slides up with `springIn` (DS §6). Reduced motion →
/// 100 ms. Radius 24 top corners from the theme.
Future<T?> showSaartheeSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool fullScreen = false,
  bool useRootNavigator = true,
}) {
  final scheme = SaartheeMotion.of(context);
  final inSpec = scheme.springIn.isInstant ? scheme.medium : scheme.springIn;
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    isScrollControlled: fullScreen,
    useSafeArea: true,
    showDragHandle: !fullScreen,
    sheetAnimationStyle: AnimationStyle(
      duration: inSpec.duration,
      curve: inSpec.curve,
      reverseDuration: scheme.medium.duration,
      reverseCurve: scheme.medium.curve,
    ),
    builder: builder,
  );
}
