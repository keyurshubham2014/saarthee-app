import 'package:flutter/widgets.dart';

import '../theme/motion.dart';

/// Small counter whose number rolls to the next value over `short` (180 ms):
/// the old number slides up and fades while the new one rises in. Badges,
/// "Me too" counts, attendees. Semantics is always the final value.
class RollingCount extends StatefulWidget {
  const RollingCount({super.key, required this.value, this.style});

  final int value;
  final TextStyle? style;

  @override
  State<RollingCount> createState() => _RollingCountState();
}

class _RollingCountState extends State<RollingCount>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    value: 1,
  );
  int? _old;

  @override
  void didUpdateWidget(RollingCount oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value == widget.value) return;
    final spec = SaartheeMotion.of(context).short;
    if (spec.isInstant) {
      _old = null;
      _c.value = 1;
      return;
    }
    _old = oldWidget.value;
    _c.duration = spec.duration;
    _c.forward(from: 0).whenCompleteOrCancel(() {
      if (mounted) setState(() => _old = null);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final up = widget.value >= (_old ?? widget.value) ? 1.0 : -1.0;
    return Semantics(
      label: '${widget.value}',
      child: ExcludeSemantics(
        child: ClipRect(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final t = SaartheeMotion.standard.transform(_c.value);
              final current = Text('${widget.value}', style: widget.style);
              if (_old == null || _c.isCompleted) return current;
              return Stack(
                alignment: Alignment.center,
                children: [
                  FractionalTranslation(
                    translation: Offset(0, -t * up),
                    child: Opacity(
                      opacity: 1 - t,
                      child: Text('$_old', style: widget.style),
                    ),
                  ),
                  FractionalTranslation(
                    translation: Offset(0, (1 - t) * up),
                    child: Opacity(opacity: t, child: current),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
