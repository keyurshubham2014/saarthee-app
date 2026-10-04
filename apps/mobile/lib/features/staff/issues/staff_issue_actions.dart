import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../moderation/moderation_models.dart';
import '../shared/staff_api.dart';
import '../shared/staff_labels.dart';
import '../shared/staff_widgets.dart';
import '../shell/staff_motion.dart';
import 'staff_issue_dialogs.dart';
import 'staff_issue_models.dart';

/// Issue tools action bar. Every destructive action has a confirm dialog
/// stating its effect; buttons are disabled with progress while in flight;
/// a 409 reloads the issue with "This issue changed while you were here."
class StaffIssueActions extends ConsumerStatefulWidget {
  const StaffIssueActions({super.key, required this.issue, this.onHandled});

  final StaffIssue issue;
  final VoidCallback? onHandled;

  @override
  ConsumerState<StaffIssueActions> createState() => _StaffIssueActionsState();
}

class _StaffIssueActionsState extends ConsumerState<StaffIssueActions> {
  String? _busy;

  StaffIssue get issue => widget.issue;

  Future<void> _run(String id, Future<void> Function(StaffApi api) call, {bool leavesQueue = false}) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = id);
    try {
      await call(ref.read(staffApiProvider));
      if (!mounted) return;
      showStaffToast(context, l10n.staffDone);
      for (final q in staffQueues) {
        ref.invalidate(staffQueueProvider(q));
      }
      if (leavesQueue) widget.onHandled?.call();
    } catch (e) {
      if (!mounted) return;
      final stale = isStaleError(e);
      // Already handled by someone else: say so and drop the row from the queue.
      showStaffToast(context, stale ? (leavesQueue ? l10n.moderationStale : l10n.staffIssueChanged) : staffErrorText(l10n, e), error: true);
      if (stale) {
        for (final q in staffQueues) {
          ref.invalidate(staffQueueProvider(q));
        }
        if (leavesQueue) widget.onHandled?.call();
      }
    } finally {
      if (mounted) setState(() => _busy = null);
      ref.invalidate(staffIssueProvider(issue.id));
    }
  }

  Widget _button(String id, String label, IconData icon, VoidCallback? onPressed) => SecondaryButton(
    key: Key('staff.action.$id'),
    label: label,
    icon: icon,
    isLoading: _busy == id,
    onPressed: _busy == null ? onPressed : null,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final open = !issue.closed;
    return Wrap(
      spacing: AppSpacing.s8,
      runSpacing: AppSpacing.s8,
      children: [
        if (!issue.moderated && open)
          _button('reviewed', l10n.staffIssueLooksFine, SaartheeIcons.check, () => _run('reviewed', (api) => api.reviewed(issue.id), leavesQueue: true)),
        if (issue.canAcknowledge)
          _button('acknowledge', l10n.staffIssueAcknowledge, SaartheeIcons.statusAcknowledged,
              () => _run('acknowledge', (api) => api.status(issue.id, 'acknowledged', expectedStatus: issue.status))),
        if (issue.canStart && issue.status != 'reported')
          _button('in_progress', l10n.staffIssueInProgress, SaartheeIcons.statusInProgress,
              () => _run('in_progress', (api) => api.status(issue.id, 'in_progress', expectedStatus: issue.status))),
        if (issue.canMarkFixed)
          _button('mark_fixed', l10n.staffIssueMarkFixed, SaartheeIcons.statusFixed, () async {
            final input = await showMarkFixedDialog(context, ref);
            if (input == null) return;
            await _run('mark_fixed', (api) async {
              final photos = <String>[if (input.photo != null) await api.uploadPhoto(input.photo!)];
              await api.status(issue.id, 'marked_fixed', note: input.note, photoIds: photos, expectedStatus: issue.status);
            });
          }),
        if (open)
          _button('change', l10n.staffIssueChange, SaartheeIcons.edit, () async {
            final change = await showRecategoriseDialog(context, issue);
            if (change == null) return;
            await _run('change', (api) => api.recategorise(issue.id, categoryId: change.categoryId, wardId: change.wardId));
          }),
        if (open)
          _button('merge', l10n.staffIssueMerge, SaartheeIcons.merge, () async {
            final target = await showMergeDialog(context, issue);
            if (target == null || !context.mounted) return;
            if (!await confirmStaffAction(context, title: l10n.staffIssueMerge, effect: l10n.staffIssueConfirmMerge)) return;
            await _run('merge', (api) => api.merge(issue.id, target), leavesQueue: true);
          }),
        _button(issue.hidden ? 'unhide' : 'hide', issue.hidden ? l10n.staffIssueUnhide : l10n.staffIssueHide,
            issue.hidden ? SaartheeIcons.visibility : SaartheeIcons.visibilityOff, () async {
          final reason = await askStaffReason(context, title: issue.hidden ? l10n.staffIssueUnhide : l10n.staffIssueHide, effect: issue.hidden ? null : l10n.staffIssueConfirmHide);
          if (reason == null) return;
          await _run(issue.hidden ? 'unhide' : 'hide', (api) => api.hide(issue.id, reason, hidden: !issue.hidden), leavesQueue: !issue.hidden);
        }),
        if (open)
          _button('reject', l10n.staffIssueReject, SaartheeIcons.block, () async {
            final input = await showRejectDialog(context);
            if (input == null || !context.mounted) return;
            if (!await confirmStaffAction(context, title: l10n.staffIssueReject, effect: l10n.staffIssueConfirmReject)) return;
            await _run('reject', (api) => api.reject(issue.id, input.reason, input.note), leavesQueue: true);
          }),
        if (issue.reporterId != null)
          _button('suspend', l10n.staffIssueSuspend, SaartheeIcons.personOff, () async {
            final reason = await askStaffReason(context, title: l10n.staffIssueSuspend, effect: l10n.staffIssueConfirmSuspend);
            if (reason == null) return;
            await _run('suspend', (api) => api.suspend(issue.reporterId!, reason));
          }),
      ],
    );
  }
}

/// One flag with Dismiss (open flags) and, for comments, "Hide comment".
class StaffFlagRow extends ConsumerWidget {
  const StaffFlagRow({super.key, required this.issue, required this.flag});

  final StaffIssue issue;
  final StaffFlag flag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    Future<void> act(Future<void> Function(StaffApi api) call) async {
      try {
        await call(ref.read(staffApiProvider));
        if (context.mounted) showStaffToast(context, l10n.staffDone);
      } catch (e) {
        if (context.mounted) showStaffToast(context, isStaleError(e) ? l10n.moderationStale : staffErrorText(l10n, e), error: true);
      }
      ref.invalidate(staffIssueProvider(issue.id));
      ref.invalidate(staffQueueProvider('flagged'));
    }

    final open = flag.status == 'open';
    return ListRow(
      key: Key('staff.flag.${flag.id}'),
      showChevron: false,
      leading: Icon(SaartheeIcons.flag, color: open ? c.warning : c.textDisabled),
      title: flagReasonLabel(l10n, flag.reason),
      subtitle: [if (flag.targetType == 'issue_event') l10n.staffEventComment, if (flag.note != null) flag.note!, if (!open) l10n.staffFlagHandled].join(' · '),
      trailing: !open
          ? null
          : Wrap(
              spacing: AppSpacing.s4,
              children: [
                if (flag.targetType == 'issue_event')
                  TextButton(
                    onPressed: () async {
                      final reason = await askStaffReason(context, title: l10n.staffCommentHide);
                      if (reason != null) await act((api) => api.hideComment(flag.targetId, reason));
                    },
                    child: Text(l10n.staffCommentHide),
                  ),
                TextButton(
                  key: Key('staff.flag.${flag.id}.dismiss'),
                  onPressed: () => act((api) => api.resolveFlag(flag.id, 'dismissed')),
                  child: Text(l10n.staffFlagDismiss),
                ),
              ],
            ),
    );
  }
}
