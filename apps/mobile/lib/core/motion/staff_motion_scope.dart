import 'package:flutter/widgets.dart';

import '../theme/motion.dart';

/// Wraps the staff console (TASK-10/11): only `short` fades, no staggers,
/// springs, shared axis or rise, and `Pressable` does not scale (DS §6 staff
/// row). Reduced motion still wins.
class StaffMotionScope extends StatelessWidget {
  const StaffMotionScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final outer = SaartheeMotion.of(context);
    return MotionSchemeOverride(
      scheme: outer.isReduced ? outer : SaartheeMotionScheme.staffScheme,
      child: child,
    );
  }
}
