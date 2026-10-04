import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/motion/motion_widgets.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/widgets.dart';

/// Step 1 tile (TASK-05 §5.4): 40 dp `CategoryBadge` + label, ≥ 96 dp tall,
/// radius 18. Pops in with the tile stagger (capped at 6 steps) on the first
/// build of a draft only; when [selected] turns on it springs to 1.02 and
/// back (`springIn`) while the fill cross-fades to `primaryContainer` and a
/// 2 px `primary` outline appears (`short`). Reduced motion → instant.
class CategoryTile extends StatefulWidget {
  const CategoryTile({
    super.key,
    required this.slug,
    required this.label,
    required this.index,
    required this.selected,
    required this.onTap,
    this.popIn = true,
  });

  final String slug;
  final String label;
  final int index;
  final bool selected;
  final bool popIn;
  final VoidCallback onTap;

  /// Pop-in order for tile [index]: tiles after the sixth start with it.
  static int staggerIndex(int index) =>
      math.min(index, SaartheeMotion.staggerMaxItems - 1);

  @override
  State<CategoryTile> createState() => CategoryTileState();
}

class CategoryTileState extends State<CategoryTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spring = AnimationController(vsync: this);

  /// Current selection-spring scale (1 at rest, peaks at 1.02).
  double get springScale =>
      1 +
      (SaartheeMotion.selectSpringScale - 1) *
          math.sin(math.pi * _spring.value);

  @override
  void didUpdateWidget(CategoryTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected && !oldWidget.selected) {
      final scheme = SaartheeMotion.of(context);
      if (!scheme.transforms) return;
      _spring.duration = scheme.springIn.duration;
      _spring.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _spring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final short = SaartheeMotion.of(context).short;
    final tile = AnimatedContainer(
      key: ValueKey('report.tile.${widget.slug}.box'),
      duration: short.duration,
      curve: short.curve,
      constraints: const BoxConstraints(minHeight: 96),
      decoration: BoxDecoration(
        color: widget.selected ? c.primaryContainer : c.surface,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: c.border),
      ),
      // The 2 px outline is a foreground decoration, so selecting never
      // changes layout (only colour animates).
      foregroundDecoration: BoxDecoration(
        borderRadius: AppRadii.cardRadius,
        border: Border.all(
          color: widget.selected ? c.primary : c.primary.withValues(alpha: 0),
          width: 2,
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.s12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CategoryBadge(slug: widget.slug),
          const SizedBox(height: AppSpacing.s8),
          Text(
            widget.label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ],
      ),
    );
    return PopIn(
      index: CategoryTile.staggerIndex(widget.index),
      animate: widget.popIn,
      child: AnimatedBuilder(
        animation: _spring,
        builder: (context, child) =>
            Transform.scale(scale: springScale, child: child),
        child: Semantics(
          button: true,
          selected: widget.selected,
          child: Pressable(
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                key: ValueKey('report.tile.${widget.slug}'),
                borderRadius: AppRadii.cardRadius,
                onTap: widget.onTap,
                child: tile,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
