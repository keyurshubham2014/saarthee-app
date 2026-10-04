import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/config/timings.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/alerts/validity_format.dart';

/// Message for a composer problem kind.
String composerProblemText(AppLocalizations l10n, String kind) =>
    switch (kind) {
      'tooLong' => l10n.staffAlertsErrTooLong,
      'tooShort' => l10n.staffAlertsErrTooShort,
      'https' => l10n.staffAlertsErrHttps,
      'window' => l10n.staffAlertsErrWindow,
      'invalid' => l10n.staffAlertsErrInvalid,
      _ => l10n.staffAlertsErrRequired,
    };

/// Server validation field path (`target.wardIds`, `titleEn`) → composer
/// field key. The area picker is `target` on the wire.
String composerServerField(String path) {
  final head = path.split('.').first;
  return head == 'target' ? 'area' : head;
}

/// Server validation issue (English zod text, never shown) → problem kind.
/// An empty ward list ("at least 1") on the area reads as "Fill this in."
String composerServerProblem(String issue, {String field = ''}) {
  final i = issue.toLowerCase();
  if (field == 'area') return 'required';
  if (i.contains('required') || i.contains('received undefined')) {
    return 'required';
  }
  if (i.contains('at most') || i.contains('too big') || i.contains('<=')) {
    return 'tooLong';
  }
  if (i.contains('at least') || i.contains('too small') || i.contains('>=')) {
    return 'tooShort';
  }
  if (i.contains('https')) return 'https';
  return 'invalid';
}

/// Label above a field (DS: labels above fields).
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.s16, bottom: AppSpacing.s4),
    child: Text(text, style: Theme.of(context).textTheme.labelLarge),
  );
}

/// Text field with a label above, a live counter and an inline error.
class ComposerTextField extends StatelessWidget {
  const ComposerTextField({
    super.key,
    required this.label,
    required this.initial,
    required this.max,
    required this.onChanged,
    this.error,
    this.focusNode,
    this.lines = 1,
  });

  final String label;
  final String initial;
  final int max;
  final ValueChanged<String> onChanged;
  final String? error;
  final FocusNode? focusNode;
  final int lines;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      FieldLabel(label),
      TextFormField(
        initialValue: initial,
        focusNode: focusNode,
        minLines: lines,
        maxLines: lines == 1 ? 1 : lines + 2,
        maxLength: max,
        maxLengthEnforcement: MaxLengthEnforcement.none,
        onChanged: onChanged,
        decoration: InputDecoration(errorText: error),
      ),
    ],
  );
}

/// IST date + time picker button.
class IstDateTimeField extends StatelessWidget {
  const IstDateTimeField({
    super.key,
    required this.label,
    required this.value,
    required this.lang,
    required this.onChanged,
    this.error,
  });

  final String label;
  final DateTime value;
  final String lang;
  final ValueChanged<DateTime> onChanged;
  final String? error;

  Future<void> _pick(BuildContext context) async {
    final ist = toIst(value);
    final day = await showDatePicker(
      context: context,
      initialDate: ist,
      firstDate: ist.subtract(AppTimings.composerPickerBack),
      lastDate: ist.add(AppTimings.composerPickerAhead),
    );
    if (day == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(ist),
    );
    if (time == null) return;
    final local = DateTime.utc(
      day.year,
      day.month,
      day.day,
      time.hour,
      time.minute,
    );
    onChanged(local.subtract(AppTimings.istOffset));
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      FieldLabel(label),
      OutlinedButton(
        onPressed: () => _pick(context),
        child: Text(formatAlertEnd(lang, value)),
      ),
      if (error != null)
        Text(error!, style: TextStyle(color: SaartheeColors.of(context).error)),
    ],
  );
}
