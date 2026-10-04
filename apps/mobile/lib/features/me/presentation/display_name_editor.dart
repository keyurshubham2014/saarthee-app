import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/application/phone_sign_in.dart';
import '../application/me_controller.dart';

/// Optional display name, 1–40 characters (never shown publicly, §5.6).
class DisplayNameEditor extends ConsumerStatefulWidget {
  const DisplayNameEditor({super.key, this.initial, this.enabled = true});

  final String? initial;
  final bool enabled;

  @override
  ConsumerState<DisplayNameEditor> createState() => _DisplayNameEditorState();
}

class _DisplayNameEditorState extends ConsumerState<DisplayNameEditor> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initial ?? '',
  );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final value = _name.text.trim();
    if (value.length > 40) {
      setState(() => _error = l10n.accountDisplayNameInvalid);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(meActionsProvider)
          .saveDisplayName(value.isEmpty ? null : value);
      if (mounted) showSaartheeToast(context, l10n.accountSaved);
    } catch (e) {
      if (mounted) setState(() => _error = authErrorText(l10n, e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LabeledTextField(
          fieldKey: const Key('me.displayName'),
          label: l10n.accountDisplayName,
          optional: true,
          controller: _name,
          enabled: widget.enabled && !_saving,
          helper: l10n.accountDisplayNameHelper,
          error: _error,
          textInputAction: TextInputAction.done,
          inputFormatters: [LengthLimitingTextInputFormatter(41)],
          onSubmitted: (_) => _save(),
        ),
        const SizedBox(height: AppSpacing.s8),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: SecondaryButton(
            key: const Key('me.displayName.save'),
            label: l10n.accountSave,
            isLoading: _saving,
            onPressed: widget.enabled ? _save : null,
          ),
        ),
      ],
    );
  }
}
