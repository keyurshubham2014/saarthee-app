import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../alerts/data/alerts_api.dart';
import '../../auth/application/session_controller.dart';
import '../data/inbox_models.dart';

/// Notification inbox (REQ-F-040): last 90 days, read state per user.
/// Read changes are optimistic and roll back on failure (AC-17).
class InboxController extends AsyncNotifier<InboxPage> {
  AlertsApi get _api => ref.read(alertsApiProvider);

  @override
  Future<InboxPage> build() async {
    final signedIn = ref.watch(sessionProvider.select((s) => s.signedIn));
    if (!signedIn) return const InboxPage(items: [], unreadCount: 0);
    return _api.inbox();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_api.inbox);
  }

  /// Marks one row read (tap, swipe or the TalkBack action). No-op if read.
  Future<void> markRead(String id) async {
    final page = state.value;
    if (page == null) return;
    final item = page.items.where((i) => i.id == id).firstOrNull;
    if (item == null || !item.unread) return;
    final now = DateTime.now();
    state = AsyncData(
      InboxPage(
        items: [for (final i in page.items) i.id == id ? i.markedRead(now) : i],
        unreadCount: (page.unreadCount - 1).clamp(0, 1 << 30),
      ),
    );
    try {
      final unread = await _api.markRead(ids: [id]);
      _setUnread(unread);
    } catch (_) {
      state = AsyncData(page);
      rethrow;
    }
  }

  Future<void> markAllRead() async {
    final page = state.value;
    if (page == null || page.unreadCount == 0) return;
    final now = DateTime.now();
    state = AsyncData(
      InboxPage(
        items: [for (final i in page.items) i.markedRead(now)],
        unreadCount: 0,
      ),
    );
    try {
      _setUnread(await _api.markRead());
    } catch (_) {
      state = AsyncData(page);
      rethrow;
    }
  }

  void _setUnread(int unread) {
    final page = state.value;
    if (page == null) return;
    state = AsyncData(InboxPage(items: page.items, unreadCount: unread));
  }
}

final inboxProvider = AsyncNotifierProvider<InboxController, InboxPage>(
  InboxController.new,
);

/// Bell badge count (0 when signed out or not loaded).
final inboxUnreadCountProvider = Provider<int>(
  (ref) => ref.watch(inboxProvider).value?.unreadCount ?? 0,
);
