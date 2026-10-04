import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/icons.dart';
import '../theme/motion.dart';
import '../theme/tokens.dart';
import 'buttons.dart';

/// Empty state (DS §5): 56 dp icon on a `primaryContainer` circle, one
/// line, one action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.message,
    this.icon = SaartheeIcons.inbox,
    this.actionLabel,
    this.onAction,
    this.debugLabel,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Shown under the message in debug builds only (placeholder owner).
  final String? debugLabel;

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            key: const Key('emptyState.icon'),
            width: AppSpacing.emptyIcon + AppSpacing.s24,
            height: AppSpacing.emptyIcon + AppSpacing.s24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.primaryContainer,
            ),
            child: Icon(
              icon,
              size: AppSpacing.emptyIcon,
              color: c.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          Text(message, textAlign: TextAlign.center, style: text.bodyLarge),
          if (debugLabel != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.s4),
              child: Text(debugLabel!, style: text.bodySmall),
            ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.s16),
            SecondaryButton(label: actionLabel!, onPressed: onAction),
          ],
        ],
      ),
    );
  }
}

/// Error state (DS §5): the cause in plain words and "Try again".
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.message,
    required this.onRetry,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String message;
  final VoidCallback onRetry;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(SaartheeIcons.error, size: AppSpacing.s40, color: c.error),
            const SizedBox(height: AppSpacing.s12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.s16),
            SecondaryButton(
              key: const Key('errorState.retry'),
              label: l10n.commonRetry,
              icon: SaartheeIcons.refresh,
              onPressed: onRetry,
            ),
            if (secondaryLabel != null && onSecondary != null) ...[
              const SizedBox(height: AppSpacing.s8),
              TertiaryButton(label: secondaryLabel!, onPressed: onSecondary),
            ],
          ],
        ),
      ),
    );
  }
}

/// Offline state for a screen with nothing cached.
class OfflineState extends StatelessWidget {
  const OfflineState({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return EmptyState(
      icon: SaartheeIcons.offline,
      message: l10n.componentOfflineState,
      actionLabel: l10n.commonRetry,
      onAction: onRetry,
    );
  }
}

/// Skeleton rows (`surfaceAlt`) with one low-contrast shimmer sweep per
/// 1.2 s (DS §6). One controller, inside a `RepaintBoundary`; disposed when
/// the list leaves the tree. Static under reduced motion. Never a
/// full-screen spinner.
class SkeletonList extends StatefulWidget {
  const SkeletonList({super.key, this.count = 6, this.twoLine = true});

  final int count;
  final bool twoLine;

  @override
  State<SkeletonList> createState() => SkeletonListState();
}

class SkeletonListState extends State<SkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: SaartheeMotion.shimmerPeriod,
  );

  /// True while the shimmer runs (tests).
  bool get isShimmering => _c.isAnimating;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // TickerMode off = content has arrived (SkeletonSwitcher): stop sweeping.
    if (SaartheeMotion.of(context).shimmer && TickerMode.valuesOf(context).enabled) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final l10n = AppLocalizations.of(context);
    Widget bar(double widthFactor, double height) => FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(AppSpacing.s8),
        ),
      ),
    );
    final rows = Column(
      children: [
        for (var i = 0; i < widget.count; i++)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.gutter,
              vertical: AppSpacing.s12,
            ),
            child: Row(
              children: [
                Container(
                  width: AppSpacing.categoryBadge,
                  height: AppSpacing.categoryBadge,
                  decoration: BoxDecoration(
                    color: c.surfaceAlt,
                    borderRadius: AppRadii.controlRadius,
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      bar(0.7, 14),
                      if (widget.twoLine) ...[
                        const SizedBox(height: AppSpacing.s8),
                        bar(0.45, 12),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
    final highlight = c.surface.withValues(alpha: c.isDark ? 0.08 : 0.5);
    return Semantics(
      label: l10n.commonLoading,
      excludeSemantics: true,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          child: rows,
          builder: (context, child) {
            if (!_c.isAnimating) return child!;
            final x = -1.5 + 3 * _c.value;
            return ShaderMask(
              blendMode: BlendMode.srcATop,
              shaderCallback: (rect) => LinearGradient(
                begin: Alignment(x - 0.6, 0),
                end: Alignment(x + 0.6, 0),
                colors: [
                  NeemFixed.transparent,
                  highlight,
                  NeemFixed.transparent,
                ],
              ).createShader(rect),
              child: child,
            );
          },
        ),
      ),
    );
  }
}

/// Skeleton → content swap: the skeleton shows while [loading]; once
/// content arrives it cross-fades in over `medium` (100 ms reduced) and the
/// shimmer controller is disposed.
class SkeletonSwitcher extends StatelessWidget {
  const SkeletonSwitcher({
    super.key,
    required this.loading,
    required this.child,
    this.skeleton = const SkeletonList(),
  });

  final bool loading;
  final Widget child;
  final Widget skeleton;

  @override
  Widget build(BuildContext context) {
    final spec = SaartheeMotion.of(context).crossFade;
    return AnimatedSwitcher(
      duration: spec.duration,
      switchInCurve: spec.curve,
      switchOutCurve: spec.curve,
      // The outgoing skeleton stops its shimmer as soon as content arrives.
      transitionBuilder: (child, animation) => TickerMode(
        enabled: loading || child.key != const ValueKey('skeleton'),
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: loading
          ? KeyedSubtree(key: const ValueKey('skeleton'), child: skeleton)
          : KeyedSubtree(key: const ValueKey('content'), child: child),
    );
  }
}
