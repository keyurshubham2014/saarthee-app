import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../alerts/data/alerts_api.dart';
import '../../auth/application/session_controller.dart';
import '../data/inbox_models.dart';

/// Notification inbox (REQ-F-040): last 90 days, read state per user.
/// Read changes are optimistic and roll back on failure (AC-17).
///
/// The provider is kept alive (the bell badge reads it), so a value loaded
/// once would otherwise be served forever: the inbox screen calls
/// [refreshIfIdle] every time it opens and pull-to-refresh calls [refresh],
/// both of which hit `GET /me/notifications` (W-FIX-ALR).
class InboxController extends AsyncNotifier<InboxPage> {
  static const _empty = InboxPage(items: [], unreadCount: 0);

  AlertsApi get _api => ref.read(alertsApiProvider);

  bool get _signedIn => ref.read(sessionProvider).signedIn;

  @override
  Future<InboxPage> build() async {
    // Keyed on the token, so a new sign-in (or another account) refetches.
    final token = ref.watch(sessionProvider.select((s) => s.token));
    if (token == null) return _empty;
    return _api.inbox();
  }

  /// Refetches, keeping the current rows on screen until the reply arrives.
  /// A failure keeps the rows that were already shown.
  Future<void> refresh() async {
    if (!_signedIn) return;
    final next = await AsyncValue.guard(_api.inbox);
    if (next.hasError && state.hasValue) {
      Error.throwWithStackTrace(next.error!, next.stackTrace!);
    }
    state = next;
  }

  /// Refetch unless a load is already in flight (opening the screen).
  Future<void> refreshIfIdle() async {
    if (state.isLoading) return;
    try {
      await refresh();
    } catch (_) {
      // Rows already shown stay; the next open or pull retries.
    }
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
