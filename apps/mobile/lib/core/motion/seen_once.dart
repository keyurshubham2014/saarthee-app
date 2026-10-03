import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// In-memory set of keys already shown in this app session.
class SeenOnceRegistry {
  final Set<String> _seen = <String>{};

  bool hasSeen(String key) => _seen.contains(key);

  /// Marks [key]; returns true when this is its first view.
  bool markFirstView(String key) => _seen.add(key);

  void reset() => _seen.clear();
}

final seenOnceProvider = Provider<SeenOnceRegistry>(
  (ref) => SeenOnceRegistry(),
);

/// Runs an entrance animation only on the first view of [seenKey] in this
/// session (DS §6: "only on first load, not when returning to the tab").
/// [builder] receives `animate`: true on the first mount of a new key, false
/// on later mounts and on every rebuild of a mounted widget.
class SeenOnce extends ConsumerStatefulWidget {
  const SeenOnce({super.key, required this.seenKey, required this.builder});

  final String seenKey;
  final Widget Function(BuildContext context, bool animate) builder;

  @override
  ConsumerState<SeenOnce> createState() => _SeenOnceState();
}

class _SeenOnceState extends ConsumerState<SeenOnce> {
  late bool _animate = ref
      .read(seenOnceProvider)
      .markFirstView(widget.seenKey);

  @override
  void didUpdateWidget(SeenOnce oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seenKey != widget.seenKey) {
      _animate = ref.read(seenOnceProvider).markFirstView(widget.seenKey);
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _animate);
}
