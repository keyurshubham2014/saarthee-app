import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../motion/seen_once.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'scorecard_bar.dart';

/// Scorecard stat tile (DS §5 stat tile: `surfaceAlt`, radius 14, numeric
/// Baloo Bhai 2 number, bodySmall label). Shared by the TASK-09 ward
/// scorecard and TASK-11's dashboard.
///
/// Motion (DS §6 "Scorecard and dashboards"): on the first view of
/// [animateKey] in this session the number counts up from 0 over `countUp`
/// showing integers only; a one-decimal value counts its integer part and
/// shows the decimal at the end. With [barFraction] a [ScorecardBar] grows
/// below the number. Rebuilds, new data and later views show final values
/// at once; reduced motion too. Semantics always read the final value.
class ScorecardStatTile extends ConsumerStatefulWidget {
  const ScorecardStatTile({
    super.key,
    required this.value,
    required this.label,
    required this.animateKey,
    this.decimals = 0,
    this.suffix = '',
    this.emptyText = '—',
    this.barFraction,
  });

  /// Null → [emptyText] (e.g. "Not enough reports yet").
  final double? value;
  final String label;
  final String animateKey;

  /// 0 (integers) or 1 (medians, rates).
  final int decimals;

  /// e.g. `%`.
  final String suffix;
  final String emptyText;
  final double? barFraction;

  @override
  ConsumerState<ScorecardStatTile> createState() => _ScorecardStatTileState();
}

class _ScorecardStatTileState extends ConsumerState<ScorecardStatTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  late final bool _firstView = ref
      .read(seenOnceProvider)
      .markFirstView(widget.animateKey);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final spec = SaartheeMotion.of(context).countUp;
    if (!_firstView || spec.isInstant || widget.value == null) {
      _c.value = 1;
      return;
    }
    _c.duration = spec.duration;
    _c.forward(from: 0);
  }

  @override
  void didUpdateWidget(ScorecardStatTile old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value || old.animateKey != widget.animateKey) {
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  String _final(double v) =>
      '${v.toStringAsFixed(widget.decimals)}${widget.suffix}';

  /// Mid-animation text: an integer between 0 and the integer part.
  String _frame(double v) {
    if (_c.value >= 1) return _final(v);
    final t = SaartheeMotion.countUp.curve.transform(_c.value);
    return '${(v.truncateToDouble() * t).round()}${widget.suffix}';
  }

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    final text = Theme.of(context).textTheme;
    final v = widget.value;
    return Semantics(
      container: true,
      label: '${widget.label}: ${v == null ? widget.emptyText : _final(v)}',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.s12),
          decoration: BoxDecoration(
            color: c.surfaceAlt,
            borderRadius: AppRadii.controlRadius,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (v == null)
                Text(
                  widget.emptyText,
                  key: const Key('scorecardTile.empty'),
                  style: text.bodyMedium?.copyWith(color: c.textSecondary),
                )
              else
                AnimatedBuilder(
                  animation: _c,
                  builder: (context, _) => Text(
                    _frame(v),
                    key: const Key('scorecardTile.value'),
                    style: AppTypography.numeric(c),
                  ),
                ),
              const SizedBox(height: AppSpacing.s4),
              Text(widget.label, style: text.bodySmall),
              if (v != null && widget.barFraction != null) ...[
                const SizedBox(height: AppSpacing.s8),
                ScorecardBar(
                  fraction: widget.barFraction!,
                  animateKey: '${widget.animateKey}:bar',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
