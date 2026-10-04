import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../shared/rep_shared.dart';
import 'rep_console_api.dart';

/// Row action sheet for `/staff/ward/issues` (AC-9/10): only the actions in
/// the server's `allowedActions` (acknowledge, mark_fixed, comment); never
/// verify, reject, merge or hide. Returns true when something changed.
Future<bool> showWardIssueActions(
  BuildContext context,
  WidgetRef ref, {
  required String issueId,
  required String status,
  required List<String> allowed,
  required bool electionActive,
}) async {
  final l10n = AppLocalizations.of(context);
  final action = await showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (allowed.contains('acknowledge'))
            ListTile(
              key: const Key('wardIssue.act.acknowledge'),
              leading: const Icon(SaartheeIcons.statusAcknowledged),
              title: Text(l10n.wardDashActAck),
              onTap: () => Navigator.pop(ctx, 'acknowledge'),
            ),
          if (allowed.contains('mark_fixed'))
            ListTile(
              key: const Key('wardIssue.act.mark_fixed'),
              leading: const Icon(SaartheeIcons.statusFixed),
              title: Text(l10n.wardDashActFixed),
              onTap: () => Navigator.pop(ctx, 'mark_fixed'),
            ),
          if (allowed.contains('comment'))
            ListTile(
              key: const Key('wardIssue.act.comment'),
              enabled: !electionActive,
              leading: const Icon(SaartheeIcons.chat),
              title: Text(l10n.wardDashActComment),
              subtitle: electionActive
                  ? Text(l10n.wardDashCommentFrozen)
                  : null,
              onTap: () => Navigator.pop(ctx, 'comment'),
            ),
        ],
      ),
    ),
  );
  if (action == null || !context.mounted) return false;
  final api = ref.read(repConsoleApiProvider);
  String? note;
  if (action != 'acknowledge') {
    note = await _askText(
      context,
      action == 'comment' ? l10n.wardDashCommentLabel : l10n.repClaimNoteLabel,
      required: action == 'comment',
    );
    if (note == null || !context.mounted) return false;
  }
  try {
    switch (action) {
      case 'acknowledge':
        await api.status(issueId, 'acknowledged', status);
      case 'mark_fixed':
        await api.status(issueId, 'marked_fixed', status, note: note);
      default:
        await api.comment(issueId, note!);
    }
    if (context.mounted) showSaartheeToast(context, l10n.wardDashActionDone);
    return true;
  } catch (e) {
    if (context.mounted) {
      showSaartheeToast(
        context,
        repErrorMessage(l10n, e),
        kind: ToastKind.error,
      );
    }
    return false;
  }
}

Future<String?> _askText(
  BuildContext context,
  String label, {
  required bool required,
}) {
  final l10n = AppLocalizations.of(context);
  final ctl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: TextField(
        key: const Key('wardIssue.text'),
        controller: ctl,
        maxLength: 500,
        maxLines: 4,
        decoration: InputDecoration(labelText: label),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l10n.repClaimCancel),
        ),
        FilledButton(
          key: const Key('wardIssue.send'),
          onPressed: () {
            final t = ctl.text.trim();
            if (required && t.isEmpty) return;
            Navigator.pop(ctx, t);
          },
          child: Text(l10n.wardDashSend),
        ),
      ],
      actionsPadding: const EdgeInsets.all(AppSpacing.s12),
    ),
  );
}
