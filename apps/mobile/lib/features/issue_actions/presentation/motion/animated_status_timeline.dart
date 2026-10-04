import 'package:flutter/material.dart';

import '../../../../core/theme/motion.dart';
import '../../../../core/theme/tokens.dart';
import '../../application/timeline_mapping.dart';

/// DS §5 status timeline whose new steps grow from their 14 dp dot
/// (REQ-F-063): the dot scales in with `springIn` while the row's height
/// expands top-down inside a `ClipRect` over `medium` and its text fades in.
/// Rows are diffed by event id: the initial list and existing rows never
/// animate. Reduced motion: new rows are present on the next frame.
class AnimatedStatusTimeline extends StatefulWidget {
  const AnimatedStatusTimeline({super.key, required this.rows, this.photo});

  final List<TimelineRow> rows;

  /// Builds the after-photo slot for a row with a `photoUrl`.
  final Widget Function(BuildContext context, String url)? photo;

  @override
  State<AnimatedStatusTimeline> createState() => _AnimatedStatusTimelineState();
}

class _AnimatedStatusTimelineState extends State<AnimatedStatusTimeline> {
  // Filled in initState (not lazily) so the first list never animates.
  Set<String> _seen = {};
  final Set<String> _animate = {};

  @override
  void initState() {
    super.initState();
    _seen = {for (final r in widget.rows) r.id};
  }

  @override
  void didUpdateWidget(AnimatedStatusTimeline old) {
    super.didUpdateWidget(old);
    for (final r in widget.rows) {
      if (!_seen.contains(r.id)) _animate.add(r.id);
    }
    _seen = {..._seen, for (final r in widget.rows) r.id};
  }

  @override
  Widget build(BuildContext context) {
    final rows = widget.rows;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++)
          _Step(
            key: ValueKey('timeline.step.${rows[i].id}'),
            row: rows[i],
            isLast: i == rows.length - 1,
            animate: _animate.contains(rows[i].id),
            photo: rows[i].photoUrl == null || widget.photo == null
                ? null
                : widget.photo!(context, rows[i].photoUrl!),
          ),
      ],
    );
  }
}

class _Step extends StatefulWidget {
  const _Step({
    super.key,
    required this.row,
    required this.isLast,
    required this.animate,
    this.photo,
  });

  final TimelineRow row;
  final bool isLast;
  final bool animate;
  final Widget? photo;

  @override
  State<_Step> createState() => _StepState();
}

class _StepState extends State<_Step> with TickerProviderStateMixin {
  late final AnimationController _dot = AnimationController(
    vsync: this,
    value: 1,
  );
  late final AnimationController _grow = AnimationController(
    vsync: this,
    value: 1,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started || !widget.animate) return;
    _started = true;
    final scheme = SaartheeMotion.of(context);
    if (scheme.springIn.isInstant || scheme.isReduced) return;
    _dot
      ..duration = scheme.springIn.duration
      ..forward(from: 0);
    _grow
      ..duration = scheme.medium.duration
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _dot.dispose();
    _grow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final text = Theme.of(context).textTheme;
    final r = widget.row;
    final grow = CurvedAnimation(
      parent: _grow,
      curve: SaartheeMotion.medium.curve,
    );
    final body = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: AppSpacing.s24,
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.s4),
                ScaleTransition(
                  key: ValueKey('timeline.dotScale.${r.id}'),
                  scale: CurvedAnimation(
                    parent: _dot,
                    curve: SaartheeMotion.springIn.curve,
                  ),
                  child: Container(
                    key: ValueKey('timeline.dot.${r.id}'),
                    width: AppSpacing.timelineDot,
                    height: AppSpacing.timelineDot,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: IssueStatusStyle.of(r.status).solid,
                    ),
                  ),
                ),
                if (!widget.isLast)
                  Expanded(child: Container(width: 2, color: c.border)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: FadeTransition(
              opacity: grow,
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.title, style: text.titleMedium),
                    if (r.actor != null || r.date != null)
                      Text(
                        [?r.actor, ?r.date].join(' · '),
                        style: text.bodySmall,
                      ),
                    if (widget.photo != null) ...[
                      const SizedBox(height: AppSpacing.s8),
                      widget.photo!,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
    return AnimatedBuilder(
      animation: grow,
      builder: (context, child) => ClipRect(
        key: ValueKey('timeline.clip.${r.id}'),
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: grow.value,
          child: child,
        ),
      ),
      child: body,
    );
  }
}
