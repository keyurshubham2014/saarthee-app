/// Shared scorecard widgets (TASK-09, reused by TASK-11's dashboard): pass
/// your own `animateKey`s; first-view tracking uses the session
/// [SeenOnceRegistry] from core/motion/seen_once.dart.
library;

export '../../motion/seen_once.dart' show SeenOnceRegistry, seenOnceProvider;
export 'scorecard_bar.dart';
export 'scorecard_stat_tile.dart';
