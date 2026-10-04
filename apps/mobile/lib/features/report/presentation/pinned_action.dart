import 'package:flutter/widgets.dart';

import '../../../core/theme/tokens.dart';

/// The primary action pinned to the bottom of a report step (DS §5): full
/// width inside the 16 dp gutters. The step screens sit in a [Column] whose
/// children are centred, so without this the 56 dp button shrinks to its
/// label (emulator bug, TASK-05 §13).
class PinnedAction extends StatelessWidget {
  const PinnedAction({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.gutter),
    child: SizedBox(width: double.infinity, child: child),
  );
}
