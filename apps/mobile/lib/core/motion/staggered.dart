import 'package:flutter/widgets.dart';

import '../theme/motion.dart';
import 'rise_in.dart';
import 'seen_once.dart';

/// Delay for item [index] in a staggered list: `index × stagger`, with items
/// after the sixth entering together with the sixth (DS §6 `stagger`).
Duration staggerDelay(SaartheeMotionScheme scheme, int index) {
  final capped = index < SaartheeMotion.staggerMaxItems
      ? index
      : SaartheeMotion.staggerMaxItems - 1;
  return scheme.stagger * capped;
}

/// Column whose children rise in 60 ms apart on first load. With
/// [seenOnceKey], the stagger runs only the first time that key is shown in
/// this session (returning to a tab shows the end state).
class StaggeredColumn extends StatelessWidget {
  const StaggeredColumn({
    super.key,
    required this.children,
    this.seenOnceKey,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
    this.mainAxisSize = MainAxisSize.min,
  });

  final List<Widget> children;
  final String? seenOnceKey;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;

  Widget _column(BuildContext context, bool animate) {
    final scheme = SaartheeMotion.of(context);
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: mainAxisSize,
      children: [
        for (var i = 0; i < children.length; i++)
          RiseIn(
            delay: staggerDelay(scheme, i),
            animate: animate,
            child: children[i],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final key = seenOnceKey;
    if (key == null) return _column(context, true);
    return SeenOnce(seenKey: key, builder: _column);
  }
}

/// Sliver version of [StaggeredColumn] for long lists (only the first six
/// animate; later items appear with the sixth or when scrolled into view).
class StaggeredSliverList extends StatelessWidget {
  const StaggeredSliverList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.seenOnceKey,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final String? seenOnceKey;

  Widget _list(BuildContext context, bool animate) {
    final scheme = SaartheeMotion.of(context);
    return SliverList.builder(
      itemCount: itemCount,
      itemBuilder: (context, i) => RiseIn(
        delay: staggerDelay(scheme, i),
        animate: animate && i < SaartheeMotion.staggerMaxItems * 2,
        child: itemBuilder(context, i),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final key = seenOnceKey;
    if (key == null) return _list(context, true);
    return SeenOnce(seenKey: key, builder: _list);
  }
}
