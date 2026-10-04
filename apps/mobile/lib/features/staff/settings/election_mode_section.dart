import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/wards/ward_providers.dart';
import '../../../core/widgets/widgets.dart';
import '../shared/staff_api.dart';
import '../shared/staff_labels.dart';
import '../shared/staff_widgets.dart';
import '../shell/staff_motion.dart';
import '../shell/staff_session.dart';

const _maxWindowDays = 120;

/// Election mode editor (TASK-10 UI over TASK-09's `PUT
/// /staff/settings/election-mode`): switch, City/Wards scope with ward
/// multi-select, From/To, notes gu/en and a banner preview.
class ElectionModeSection extends ConsumerStatefulWidget {
  const ElectionModeSection({
    super.key,
    required this.initial,
    required this.readOnly,
  });

  final Json initial;
  final bool readOnly;

  @override
  ConsumerState<ElectionModeSection> createState() =>
      _ElectionModeSectionState();
}

class _ElectionModeSectionState extends ConsumerState<ElectionModeSection> {
  late bool _enabled = widget.initial['enabled'] == true;
  late String _scope = '${widget.initial['scope'] ?? 'city'}';
  late final Set<String> _wards = {
    for (final w in (widget.initial['wardIds'] as List? ?? const [])) '$w',
  };
  late DateTime _from = _date(widget.initial['from']) ?? DateTime.now();
  late DateTime _to = _date(widget.initial['to']) ?? DateTime.now();
  late final _noteEn = TextEditingController(
    text: '${widget.initial['note_en'] ?? ''}',
  );
  late final _noteGu = TextEditingController(
    text: '${widget.initial['note_gu'] ?? ''}',
  );
  bool _saving = false;
  String? _error;

  static DateTime? _date(Object? v) {
    final d = DateTime.tryParse('$v');
    return d == null || d.year < 2000 ? null : d.toLocal();
  }

  @override
  void dispose() {
    _noteEn.dispose();
    _noteGu.dispose();
    super.dispose();
  }

  Future<void> _pick(bool from) async {
    final initial = from ? _from : _to;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => from ? _from = picked : _to = picked);
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final days = _to.difference(_from).inDays;
    if (!_to.isAfter(_from) || days > _maxWindowDays) {
      return setState(() => _error = l10n.staffSettingsDateError);
    }
    if (_scope == 'wards' && _wards.isEmpty) {
      return setState(() => _error = l10n.staffSettingsWardsError);
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      await ref
          .read(apiClientProvider)
          .putJson(
            '/staff/settings/election-mode',
            headers: ref.read(staffAuthHeadersProvider),
            body: {
              'enabled': _enabled,
              'scope': _scope,
              'wardIds': _scope == 'wards' ? _wards.toList() : <String>[],
              'from': _from.toUtc().toIso8601String(),
              'to': _to.toUtc().toIso8601String(),
              'note_en': _noteEn.text.trim(),
              'note_gu': _noteGu.text.trim(),
            },
          );
      if (mounted) showStaffToast(context, l10n.staffDone);
    } catch (e) {
      if (mounted) setState(() => _error = staffErrorText(l10n, e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final ro = widget.readOnly;
    final wards = ref.watch(wardsListProvider).value?.wards ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          key: const Key('staff.election.enabled'),
          contentPadding: EdgeInsets.zero,
          value: _enabled,
          title: Text(l10n.staffSettingsElectionOn),
          onChanged: ro ? null : (v) => setState(() => _enabled = v),
        ),
        Text(
          l10n.staffSettingsScope,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: AppSpacing.s8),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(
              value: 'city',
              label: Text(l10n.staffSettingsScopeCity),
            ),
            ButtonSegment(
              value: 'wards',
              label: Text(l10n.staffSettingsScopeWards),
            ),
          ],
          selected: {_scope},
          onSelectionChanged: ro
              ? null
              : (s) => setState(() => _scope = s.first),
        ),
        if (_scope == 'wards') ...[
          const SizedBox(height: AppSpacing.s8),
          Text(l10n.staffSettingsWardsCount(_wards.length)),
          Wrap(
            spacing: AppSpacing.s4,
            runSpacing: AppSpacing.s4,
            children: [
              for (final w in wards)
                FilterChip(
                  label: Text(staffWardText(w, lang)),
                  selected: _wards.contains(w.id),
                  onSelected: ro
                      ? null
                      : (v) => setState(
                          () => v ? _wards.add(w.id) : _wards.remove(w.id),
                        ),
                ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.s12),
        Wrap(
          spacing: AppSpacing.s8,
          children: [
            OutlinedButton(
              onPressed: ro ? null : () => _pick(true),
              child: Text(
                '${l10n.staffSettingsFrom}: ${Formatters.date(_from)}',
              ),
            ),
            OutlinedButton(
              onPressed: ro ? null : () => _pick(false),
              child: Text('${l10n.staffSettingsTo}: ${Formatters.date(_to)}'),
            ),
          ],
        ),
        TextField(
          controller: _noteEn,
          enabled: !ro,
          maxLength: 200,
          decoration: InputDecoration(labelText: l10n.staffSettingsNoteEn),
          onChanged: (_) => setState(() {}),
        ),
        TextField(
          controller: _noteGu,
          enabled: !ro,
          maxLength: 200,
          decoration: InputDecoration(labelText: l10n.staffSettingsNoteGu),
          onChanged: (_) => setState(() {}),
        ),
        Text(
          l10n.staffSettingsPreview,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: AppSpacing.s8),
        NoticeBanner(
          key: const Key('staff.election.preview'),
          kind: NoticeKind.electionMode,
          message: (lang == 'gu' ? _noteGu.text : _noteEn.text).trim().isEmpty
              ? null
              : (lang == 'gu' ? _noteGu.text : _noteEn.text).trim(),
          rounded: true,
        ),
        if (_error != null) InlineFieldError(message: _error!),
        if (!ro) ...[
          const SizedBox(height: AppSpacing.s12),
          PrimaryButton(
            key: const Key('staff.election.save'),
            label: l10n.staffSettingsSaveElection,
            isLoading: _saving,
            onPressed: _save,
          ),
        ],
      ],
    );
  }
}
