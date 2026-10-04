import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/motion/motion_widgets.dart';
import '../../../../core/theme/tokens.dart';

/// Photo captured → a thumbnail overlay flies from the "Take photo" button
/// rect to its slot rect (translate + scale, `long`), then is removed so the
/// slot shows the real thumbnail (DS §6). Reduced motion → no overlay.
/// Returns when the flight is over.
Future<void> flyPhotoIn({
  required BuildContext context,
  required Rect from,
  required Rect to,
  required ImageProvider image,
}) {
  final scheme = SaartheeMotion.of(context);
  if (!scheme.transforms) return Future.value();
  final overlay = Overlay.of(context);
  final done = Completer<void>();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => FlyingThumb(
      from: from,
      to: to,
      image: image,
      spec: scheme.long,
      onEnd: () {
        entry.remove();
        if (!done.isCompleted) done.complete();
      },
    ),
  );
  overlay.insert(entry);
  return done.future;
}

/// Global rect of the widget behind [key], or null when not laid out.
Rect? globalRectOf(GlobalKey key) {
  final box = key.currentContext?.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

class FlyingThumb extends StatefulWidget {
  const FlyingThumb({
    super.key,
    required this.from,
    required this.to,
    required this.image,
    required this.spec,
    required this.onEnd,
  });

  final Rect from;
  final Rect to;
  final ImageProvider image;
  final MotionSpec spec;
  final VoidCallback onEnd;

  @override
  State<FlyingThumb> createState() => FlyingThumbState();
}

class FlyingThumbState extends State<FlyingThumb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.spec.duration,
  );

  /// Current rect of the flying thumbnail (tests).
  Rect get rect =>
      Rect.lerp(widget.from, widget.to, widget.spec.curve.transform(_c.value))!;

  @override
  void initState() {
    super.initState();
    _c.forward().whenComplete(widget.onEnd);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        // Translate + scale of a slot-sized box (transform only).
        final r = rect;
        final sx = r.width / widget.to.width;
        final sy = r.height / widget.to.height;
        return Stack(
          children: [
            Positioned.fromRect(
              rect: widget.to,
              child: Transform(
                alignment: Alignment.topLeft,
                transform: Matrix4.identity()
                  ..translateByDouble(
                    r.left - widget.to.left,
                    r.top - widget.to.top,
                    0,
                    1,
                  )
                  ..scaleByDouble(sx, sy, 1, 1),
                child: child,
              ),
            ),
          ],
        );
      },
      child: ClipRRect(
        key: const Key('report.flyIn'),
        borderRadius: AppRadii.controlRadius,
        child: Image(image: widget.image, fit: BoxFit.cover),
      ),
    ),
  );
}
