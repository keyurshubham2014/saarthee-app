import 'package:flutter/material.dart' hide ErrorSummary;

import '../../../../core/api/app_error.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../services/data/service_models.dart' show parseSteps;
import '../../shared/staff_errors.dart';

/// Server validation issue (English zod text, never shown) → ARB text.
String contentServerIssue(AppLocalizations l10n, String issue) {
  final i = issue.toLowerCase();
  if (i.contains('required') || i.contains('received undefined')) {
    return l10n.staffContentErrorRequired;
  }
  if (i.contains('https') || i.contains('url')) {
    return l10n.staffContentErrorHttps;
  }
  return l10n.errorValidationFailed;
}

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
    this.stepsPreview = false,
  }) : isSwitch = false,
       initialBool = false,
       options = null;

  const FieldSpec.toggle(this.name, this.label, {this.initialBool = false})
    : isSwitch = true,
      initial = '',
      validator = null,
      maxLines = 1,
      keyboardType = null,
      stepsPreview = false,
      options = null;

  /// Dropdown of fixed API values; [options] maps value → shown label. The
  /// submitted value is the API value (a string, like text fields).
  const FieldSpec.choice(
    this.name,
    this.label, {
    required Map<String, String> this.options,
    this.initial = '',
  }) : isSwitch = false,
       initialBool = false,
       validator = null,
       maxLines = 1,
       keyboardType = null,
       stepsPreview = false;

  /// Value → label for a dropdown field (null for text and switch fields).
  final Map<String, String>? options;

  /// Shows the numbered steps as citizens will see them, under the field.
  final bool stepsPreview;

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
      final e = f.options != null && _text[f.name]!.text.isEmpty
          ? AppLocalizations.of(context).staffContentErrorRequired
          : f.validator?.call(_text[f.name]?.text ?? '');
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
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      server = {
        for (final d in e.details)
          d.field.split('.').first: contentServerIssue(l10n, d.issue),
      };
      if (server.isEmpty) server = {'_': staffErrorMessage(l10n, e)};
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      _errors = server ?? {};
    });
  }

  Widget _field(FieldSpec f) {
    final options = f.options;
    if (options != null) {
      final current = _text[f.name]!.text;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(f.label, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.s8),
          DropdownButtonFormField<String>(
            key: Key('form.${f.name}'),
            initialValue: options.containsKey(current) ? current : null,
            isExpanded: true,
            decoration: InputDecoration(errorText: _errors[f.name]),
            items: [
              for (final o in options.entries)
                DropdownMenuItem(value: o.key, child: Text(o.value)),
            ],
            onChanged: (v) => setState(() => _text[f.name]!.text = v ?? ''),
          ),
        ],
      );
    }
    if (f.isSwitch) {
      return SwitchListTile(
        key: Key('form.${f.name}'),
        contentPadding: EdgeInsets.zero,
        title: Text(f.label),
        value: _bools[f.name]!,
        onChanged: (v) => setState(() => _bools[f.name] = v),
      );
    }
    final field = LabeledTextField(
      fieldKey: Key('form.${f.name}'),
      label: f.label,
      controller: _text[f.name],
      error: _errors[f.name],
      maxLines: f.maxLines,
      keyboardType: f.keyboardType,
    );
    if (!f.stepsPreview) return field;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        field,
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _text[f.name]!,
          builder: (context, value, _) {
            final steps = parseSteps(value.text);
            if (steps.isEmpty) return const SizedBox.shrink();
            return Padding(
              key: Key('form.${f.name}.preview'),
              padding: const EdgeInsets.only(top: AppSpacing.s8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context).staffContentStepsPreview,
                    style: text.labelMedium,
                  ),
                  for (var i = 0; i < steps.length; i++)
                    Text('${i + 1}. ${steps[i]}', style: text.bodySmall),
                ],
              ),
            );
          },
        ),
      ],
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
