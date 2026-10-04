import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../shared/rep_shared.dart';

const claimMethods = [
  'certificate_of_election',
  'official_gazette',
  'in_person',
  'official_email',
];

/// "Approve claim": a verification method is required. Returns the method.
Future<String?> showApproveDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  String? method;
  String? error;
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text(l10n.repClaimApproveTitle),
        content: DropdownButtonFormField<String>(
          key: const Key('claim.method'),
          initialValue: method,
          decoration: InputDecoration(
            labelText: l10n.repClaimMethodLabel,
            errorText: error,
          ),
          items: [
            for (final m in claimMethods)
              DropdownMenuItem(value: m, child: Text(repMethodLabel(l10n, m))),
          ],
          onChanged: (v) => set(() => (method, error) = (v, null)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.repClaimCancel),
          ),
          FilledButton(
            key: const Key('claim.approve.confirm'),
            onPressed: () => method == null
                ? set(() => error = l10n.repClaimMethodRequired)
                : Navigator.pop(ctx, method),
            child: Text(l10n.repClaimApprove),
          ),
        ],
      ),
    ),
  );
}

/// Reason dialog (5–300 characters) for reject and revoke.
Future<String?> showReasonDialog(
  BuildContext context,
  String title,
  String confirm,
) {
  final l10n = AppLocalizations.of(context);
  final ctl = TextEditingController();
  String? error;
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text(title),
        content: TextField(
          key: const Key('claim.reason'),
          controller: ctl,
          maxLength: 300,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: l10n.repClaimReasonLabel,
            errorText: error,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.repClaimCancel),
          ),
          FilledButton(
            key: const Key('claim.reason.confirm'),
            onPressed: () {
              final t = ctl.text.trim();
              if (t.length < 5 || t.length > 300) {
                set(() => error = l10n.repClaimReasonError);
              } else {
                Navigator.pop(ctx, t);
              }
            },
            child: Text(confirm),
          ),
        ],
      ),
    ),
  );
}
