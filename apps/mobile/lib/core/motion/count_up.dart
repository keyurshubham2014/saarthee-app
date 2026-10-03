import 'package:flutter/widgets.dart';

import '../theme/motion.dart';

/// Integer count from the previous value (0 on first sight) to [value] over
/// `countUp` (600 ms, easeOutCubic). Shows integers only, does not replay on
/// a rebuild with the same value, and its semantics is always the final
/// value. Reduced motion → final value on the first frame.
class CountUp extends StatefulWidget {
  const CountUp({
    super.key,
    required this.value,
    this.style,
    this.animate = true,
    this.format,
  });

  final int value;
  final TextStyle? style;
  final bool animate;
  final String Function(int value)? format;

  @override
  State<CountUp> createState() => _CountUpState();
}

class _CountUpState extends State<CountUp> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  int _from = 0;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _run(0);
  }

  void _run(int from) {
    final spec = SaartheeMotion.of(context).countUp;
    _from = from;
    if (!widget.animate || spec.isInstant) {
      _c.value = 1;
      return;
    }
    _c.duration = spec.duration;
    _c.forward(from: 0);
  }

  @override
  void didUpdateWidget(CountUp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _run(_current);
  }

  int get _current {
    final t = SaartheeMotion.countUp.curve.transform(_c.value);
    return (_from + (widget.value - _from) * t).round();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = widget.format ?? (int v) => '$v';
    return Semantics(
      label: fmt(widget.value),
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => Text(fmt(_current), style: widget.style),
        ),
      ),
    );
  }
}
