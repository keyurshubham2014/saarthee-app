import 'package:flutter/material.dart';

/// App-wide scrolling without Android 12's stretch overscroll, which scaled
/// every list vertically at its edges and read as the UI "magnifying".
/// Lists stop at their edges (clamping physics, unchanged); pull-to-refresh
/// keeps its own chevron indicator, which listens to overscroll notifications.
class SaartheeScrollBehavior extends MaterialScrollBehavior {
  const SaartheeScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}
