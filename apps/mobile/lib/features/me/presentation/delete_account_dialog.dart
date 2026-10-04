import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/application/phone_sign_in.dart';
import '../application/me_controller.dart';

/// "Delete your account?" (TASK-04 §5.4). "Delete account" stays disabled
/// until the person types DELETE. Returns true after a successful deletion.
Future<bool> showDeleteAccountDialog(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => const _DeleteAccountDialog(),
  );
  return ok == true;
}

class _DeleteAccountDialog extends ConsumerStatefulWidget {
  const _DeleteAccountDialog();

  @override
  ConsumerState<_DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  final _confirm = TextEditingController();
  bool _deleting = false;
  String? _error;

  @override
  void dispose() {
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await ref.read(meActionsProvider).deleteAccount();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _deleting = false;
          _error = authErrorText(l10n, e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    final ready = _confirm.text == 'DELETE' && !_deleting;
    return AlertDialog(
      key: const Key('delete.dialog'),
      title: Text(l10n.accountDeleteTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.accountDeleteBody),
            const SizedBox(height: AppSpacing.s16),
            LabeledTextField(
              fieldKey: const Key('delete.confirm'),
              label: l10n.accountDeleteTypeLabel,
              controller: _confirm,
              enabled: !_deleting,
              onChanged: (_) => setState(() {}),
              error: _error,
            ),
            if (_deleting) ...[
              const SizedBox(height: AppSpacing.s16),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('delete.cancel'),
          onPressed: _deleting ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.accountDeleteCancel),
        ),
        TextButton(
          key: const Key('delete.confirmButton'),
          style: TextButton.styleFrom(foregroundColor: c.error),
          onPressed: ready ? _delete : null,
          child: Text(l10n.accountDeleteConfirm),
        ),
      ],
    );
  }
}
