import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/discovery_api.dart';
import '../data/discovery_models.dart';

/// Viewer's Me too / Follow state for one issue (optimistic, REQ-F-031).
class SocialState {
  const SocialState({
    this.hasMeToo = false,
    this.meTooCount = 0,
    this.isFollowing = false,
    this.seeded = false,
  });

  final bool hasMeToo, isFollowing, seeded;
  final int meTooCount;

  SocialState copyWith({bool? hasMeToo, int? meTooCount, bool? isFollowing}) =>
      SocialState(
        hasMeToo: hasMeToo ?? this.hasMeToo,
        meTooCount: meTooCount ?? this.meTooCount,
        isFollowing: isFollowing ?? this.isFollowing,
        seeded: true,
      );
}

final socialProvider = NotifierProvider.autoDispose
    .family<SocialController, SocialState, String>(SocialController.new);

class SocialController extends Notifier<SocialState> {
  SocialController(this.issueId);

  final String issueId;
  bool _busy = false;

  @override
  SocialState build() => const SocialState();

  /// Takes the server state from a freshly loaded detail.
  void seed(IssueDetail d) {
    if (_busy) return;
    state = SocialState(
      hasMeToo: d.viewer.hasMeToo,
      meTooCount: d.meTooCount,
      isFollowing: d.viewer.isFollowing,
      seeded: true,
    );
  }

  /// Toggles Me too optimistically (Me too also follows). Returns false and
  /// rolls the count back when the server refuses or the network fails.
  Future<bool> toggleMeToo() async {
    if (_busy) return true;
    _busy = true;
    final before = state;
    final on = !before.hasMeToo;
    state = before.copyWith(
      hasMeToo: on,
      meTooCount: before.meTooCount + (on ? 1 : -1),
      isFollowing: on ? true : before.isFollowing,
    );
    try {
      final (count, _) = await ref
          .read(discoveryApiProvider)
          .meToo(issueId, on: on);
      if (ref.mounted) state = state.copyWith(meTooCount: count);
      return true;
    } catch (_) {
      if (ref.mounted) state = before;
      return false;
    } finally {
      _busy = false;
    }
  }

  /// Toggles Follow optimistically; rolls back on failure.
  Future<bool> toggleFollow() async {
    if (_busy) return true;
    _busy = true;
    final before = state;
    final on = !before.isFollowing;
    state = before.copyWith(isFollowing: on);
    try {
      await ref.read(discoveryApiProvider).follow(issueId, on: on);
      return true;
    } catch (_) {
      if (ref.mounted) state = before;
      return false;
    } finally {
      _busy = false;
    }
  }
}
