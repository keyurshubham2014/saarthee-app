import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/app_error.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../application/issue_providers.dart';
import '../data/issue_actions_api.dart';
import '../data/issue_models.dart';
import 'common.dart';
import 'motion/send_progress_button.dart';

/// Role-aware status buttons (TASK-06 §5.4): "Acknowledge", "Start work",
/// "Mark as fixed", "Reject" — only those the server says the viewer may
/// use. Reused by TASK-07 detail and TASK-10/11 consoles. In-flight button
/// shows in-button progress; `STALE_STATUS` shows the message and Reload.
class IssueStatusActions extends ConsumerStatefulWidget {
  const IssueStatusActions({super.key, required this.issue});

  final IssueLifecycle issue;

  @override
  ConsumerState<IssueStatusActions> createState() => _IssueStatusActionsState();
}

class _IssueStatusActionsState extends ConsumerState<IssueStatusActions> {
  String? _busy;
  String? _error;
  bool _stale = false;
  final Map<String, String> _actionIds = {};

  Future<void> _change(String to, {String? note}) async {
    final l10n = AppLocalizations.of(context);
    final issue = widget.issue;
    setState(() {
      _busy = to;
      _error = null;
      _stale = false;
    });
    try {
      await ref
          .read(issueActionsApiProvider)
          .changeStatus(
            issue.id,
            to: to,
            expectedStatus: issue.apiStatus,
            clientActionId: _actionIds.putIfAbsent(
              '$to@${issue.statusVersion}',
              newActionId,
            ),
            note: note,
          );
      if (!mounted) return;
      showSaartheeToast(context, l10n.issueActionsUpdated);
      refreshIssue(ref, issue.id);
    } on AppError catch (e) {
      if (!mounted) return;
      setState(() {
        _stale = e.code == 'STALE_STATUS';
        _error = lifecycleErrorMessage(l10n, e);
      });
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _reject() async {
    final l10n = AppLocalizations.of(context);
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l10n.issueActionsReject),
        content: LabeledTextField(
          fieldKey: const Key('issueActions.rejectReason'),
          label: l10n.issueActionsRejectReason,
          controller: reason,
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(l10n.commonBack),
          ),
          TextButton(
            key: const Key('issueActions.rejectConfirm'),
            onPressed: () => Navigator.pop(c, reason.text.trim().isNotEmpty),
            child: Text(l10n.issueActionsReject),
          ),
        ],
      ),
    );
    final note = reason.text.trim();
    reason.dispose();
    if (ok == true) await _change('rejected', note: note);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final a = widget.issue.actions;
    final buttons = <(String, String, VoidCallback)>[
      if (a.acknowledge)
        (
          'acknowledged',
          l10n.issueActionsAcknowledge,
          () => _change('acknowledged'),
        ),
      if (a.start)
        (
          'in_progress',
          l10n.issueActionsStartWork,
          () => _change('in_progress'),
        ),
      if (a.markFixed)
        (
          'marked_fixed',
          l10n.issueActionsMarkFixedTitle,
          () => context.push('/issues/${widget.issue.id}/mark-fixed'),
        ),
      if (a.reject) ('rejected', l10n.issueActionsReject, _reject),
    ];
    if (buttons.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (to, label, onTap) in buttons) ...[
          SendProgressButton(
            key: ValueKey('issueActions.$to'),
            label: label,
            pinned: false,
            sending: _busy == to,
            onPressed: _busy == null ? onTap : null,
          ),
          const SizedBox(height: AppSpacing.s8),
        ],
        if (_error != null)
          InlineFieldError(
            key: const Key('issueActions.error'),
            message: _error!,
          ),
        if (_stale)
          TertiaryButton(
            key: const Key('issueActions.reload'),
            label: l10n.issueActionsReload,
            onPressed: () {
              setState(() {
                _stale = false;
                _error = null;
              });
              refreshIssue(ref, widget.issue.id);
            },
          ),
      ],
    );
  }
}
