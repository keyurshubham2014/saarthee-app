import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Centers content at max 560 wide with 20 px screen padding (02 §2.2).
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child, this.padded = true});

  final Widget child;
  final bool padded;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
        child: padded
            ? Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screen,
                ),
                child: child,
              )
            : child,
      ),
    );
  }
}

/// Scrolling body with an optional bottom area pinned above the keyboard.
/// Used by onboarding, confirmation and step layouts (02 §3.3).
class PinnedBottomLayout extends StatelessWidget {
  const PinnedBottomLayout({
    super.key,
    required this.children,
    this.bottom = const [],
    this.top,
  });

  final Widget? top;
  final List<Widget> children;
  final List<Widget> bottom;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          ?top,
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(
                top: AppSpacing.lg,
                bottom: AppSpacing.xl,
              ),
              child: ContentWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          ),
          if (bottom.isNotEmpty)
            Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              padding: const EdgeInsets.only(
                top: AppSpacing.md,
                bottom: AppSpacing.lg,
              ),
              child: ContentWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < bottom.length; i++) ...[
                      if (i > 0) const SizedBox(height: AppSpacing.sm),
                      bottom[i],
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
