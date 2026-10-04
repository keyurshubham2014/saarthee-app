import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/push/foreground_push.dart';
import '../../auth/application/session_controller.dart';
import '../data/issue_actions_api.dart';
import '../data/issue_models.dart';

/// Lifecycle view of an issue (status, derived fields, viewer actions).
final issueLifecycleProvider = FutureProvider.autoDispose
    .family<IssueLifecycle, String>((ref, id) {
      // The viewer's actions (verify, mark fixed …) depend on who is signed in:
      // refetch when the session is restored at start-up or changes.
      ref.watch(sessionProvider.select((s) => s.token));
      _refreshOnPush(ref, id);
      return ref.watch(issueActionsApiProvider).lifecycle(id);
    });

/// Every timeline event of an issue, oldest first (pages of 50 merged).
final issueEventsProvider = FutureProvider.autoDispose
    .family<List<IssueEventItem>, String>((ref, id) async {
      _refreshOnPush(ref, id);
      final api = ref.watch(issueActionsApiProvider);
      final all = <IssueEventItem>[];
      String? cursor;
      do {
        final (items, next) = await api.events(id, cursor: cursor);
        all.addAll(items);
        cursor = next;
      } while (cursor != null && all.length < 500);
      return all;
    });

/// A foreground `issue_update` push for this issue refreshes the screen, so
/// the chip and timeline animate the change (AC-13).
void _refreshOnPush(Ref ref, String id) {
  final sub = ref
      .watch(foregroundPushProvider)
      .messages
      .where((m) => m['kind'] == 'issue_update' && m['refId'] == id)
      .listen((_) => ref.invalidateSelf());
  ref.onDispose(sub.cancel);
}

/// Reloads both after the user's own action;
/// the chip and timeline then animate the change.
void refreshIssue(WidgetRef ref, String id) {
  ref.invalidate(issueLifecycleProvider(id));
  ref.invalidate(issueEventsProvider(id));
}
