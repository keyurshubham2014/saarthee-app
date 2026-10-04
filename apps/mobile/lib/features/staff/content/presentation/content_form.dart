import 'package:flutter/material.dart' hide ErrorSummary;

import '../../../../core/api/app_error.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/widgets.dart';

/// One form field. Text fields validate with [validator]; switches use
/// [initialBool].
class FieldSpec {
  const FieldSpec.text(
    this.name,
    this.label, {
    this.initial = '',
    this.validator,
    this.maxLines = 1,
    this.keyboardType,
  }) : isSwitch = false,
       initialBool = false;

  const FieldSpec.toggle(this.name, this.label, {this.initialBool = false})
    : isSwitch = true,
      initial = '',
      validator = null,
      maxLines = 1,
      keyboardType = null;

  final String name;
  final String label;
  final String initial;
  final bool initialBool;
  final bool isSwitch;
  final String? Function(String value)? validator;
  final int maxLines;
  final TextInputType? keyboardType;
}

/// Submitted values: text fields as trimmed strings, switches as bools.
typedef FormValues = Map<String, Object>;

/// Staff form (TASK-12 §5.4): label-above inputs, an error summary on top,
/// en/gu pairs side by side at ≥ 900 dp. [onSubmit] returns null on success
/// or the server's field errors (shown inline).
class ContentForm extends StatefulWidget {
  const ContentForm({
    super.key,
    required this.rows,
    required this.onSubmit,
    required this.submitLabel,
  });

  /// Each row holds one field, or an en/gu pair.
  final List<List<FieldSpec>> rows;
  final Future<Map<String, String>?> Function(FormValues values) onSubmit;
  final String submitLabel;

  @override
  State<ContentForm> createState() => _ContentFormState();
}

class _ContentFormState extends State<ContentForm> {
  late final Map<String, TextEditingController> _text = {
    for (final f in widget.rows.expand((r) => r))
      if (!f.isSwitch) f.name: TextEditingController(text: f.initial),
  };
  late final Map<String, bool> _bools = {
    for (final f in widget.rows.expand((r) => r))
      if (f.isSwitch) f.name: f.initialBool,
  };
  Map<String, String> _errors = {};
  bool _saving = false;

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final errors = <String, String>{};
    for (final f in widget.rows.expand((r) => r)) {
      final e = f.validator?.call(_text[f.name]?.text ?? '');
      if (e != null) errors[f.name] = e;
    }
    setState(() => _errors = errors);
    if (errors.isNotEmpty) return;
    setState(() => _saving = true);
    final values = <String, Object>{
      for (final e in _text.entries) e.key: e.value.text.trim(),
      ..._bools,
    };
    Map<String, String>? server;
    try {
      server = await widget.onSubmit(values);
    } on AppError catch (e) {
      server = {for (final d in e.details) d.field: d.issue};
      if (server.isEmpty) server = {'_': e.message};
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      _errors = server ?? {};
    });
  }

  Widget _field(FieldSpec f) {
    if (f.isSwitch) {
      return SwitchListTile(
        key: Key('form.${f.name}'),
        contentPadding: EdgeInsets.zero,
        title: Text(f.label),
        value: _bools[f.name]!,
        onChanged: (v) => setState(() => _bools[f.name] = v),
      );
    }
    return LabeledTextField(
      fieldKey: Key('form.${f.name}'),
      label: f.label,
      controller: _text[f.name],
      error: _errors[f.name],
      maxLines: f.maxLines,
      keyboardType: f.keyboardType,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final labels = {
      for (final f in widget.rows.expand((r) => r)) f.name: f.label,
    };
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      children: [
        if (_errors.isNotEmpty) ...[
          ErrorSummary(
            key: const Key('form.errors'),
            title: l10n.staffContentErrorSummary,
            items: [
              for (final e in _errors.entries)
                ErrorSummaryItem(
                  '${labels[e.key] ?? ''}${labels[e.key] == null ? '' : ': '}${e.value}',
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s16),
        ],
        for (final row in widget.rows)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s12),
            child: wide && row.length > 1
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < row.length; i++) ...[
                        if (i > 0) const SizedBox(width: AppSpacing.s16),
                        Expanded(child: _field(row[i])),
                      ],
                    ],
                  )
                : Column(
                    children: [
                      for (var i = 0; i < row.length; i++) ...[
                        if (i > 0) const SizedBox(height: AppSpacing.s12),
                        _field(row[i]),
                      ],
                    ],
                  ),
          ),
        PrimaryButton(
          key: const Key('form.save'),
          label: widget.submitLabel,
          isLoading: _saving,
          onPressed: _submit,
        ),
      ],
    );
  }
}
