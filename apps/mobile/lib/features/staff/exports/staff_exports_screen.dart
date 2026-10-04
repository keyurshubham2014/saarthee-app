import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/api/app_error.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/wards/ward_providers.dart';
import '../../../core/widgets/widgets.dart';
import '../shared/staff_api.dart';
import '../shared/staff_labels.dart';
import '../shared/staff_shared.dart';
import '../shared/staff_widgets.dart';
import '../shell/staff_motion.dart';

/// Hands the CSV to the user: share sheet in the app, a download on the web
/// (share_plus falls back to downloading files). Faked in tests.
final staffCsvSaverProvider = Provider<Future<void> Function(String name, List<int> bytes)>(
  (ref) => (name, bytes) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile.fromData(Uint8List.fromList(bytes), mimeType: 'text/csv', name: name)], fileNameOverrides: [name]),
    );
  },
);

String _ymd(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// The export query, or an error text (phone opt-in needs a 10–200 reason).
({Map<String, String>? query, String? error}) buildExportQuery(
  AppLocalizations l10n, {
  required String dataset,
  required DateTime from,
  required DateTime to,
  String? wardId,
  required bool includePhone,
  required String reason,
}) {
  final days = to.difference(from).inDays;
  if (days < 0 || days > 366) return (query: null, error: l10n.staffExportRangeError);
  final r = reason.trim();
  if (includePhone && (r.length < 10 || r.length > 200)) return (query: null, error: l10n.staffExportReasonError);
  return (
    query: {
      'dataset': dataset,
      'from': _ymd(from),
      'to': _ymd(to),
      'ward': ?wardId,
      'includePhone': '$includePhone',
      if (includePhone) 'reason': r,
    },
    error: null,
  );
}

/// Exports (TASK-10 §5.4, P1): dataset, date range, ward, phone opt-in with
/// reason and warning → "Download CSV".
class StaffExportsScreen extends ConsumerStatefulWidget {
  const StaffExportsScreen({super.key});

  @override
  ConsumerState<StaffExportsScreen> createState() => _StaffExportsScreenState();
}

class _StaffExportsScreenState extends ConsumerState<StaffExportsScreen> {
  String _dataset = 'issues';
  DateTime _to = DateTime.now();
  late DateTime _from = DateTime(_to.year, _to.month - 1, _to.day);
  String? _ward;
  bool _phone = false;
  final _reason = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pick(bool from) async {
    final picked = await showDatePicker(context: context, initialDate: from ? _from : _to, firstDate: DateTime(2024), lastDate: DateTime.now());
    if (picked != null) setState(() => from ? _from = picked : _to = picked);
  }

  Future<void> _download() async {
    final l10n = AppLocalizations.of(context);
    final q = buildExportQuery(l10n, dataset: _dataset, from: _from, to: _to, wardId: _ward, includePhone: _phone, reason: _reason.text);
    setState(() => _error = q.error);
    if (q.query == null) return;
    setState(() => _busy = true);
    try {
      final bytes = await ref.read(staffApiProvider).export(q.query!);
      final rows = '\n'.allMatches(String.fromCharCodes(bytes)).length - 1;
      await ref.read(staffCsvSaverProvider)('saarthee-$_dataset-${q.query!['from']}-to-${q.query!['to']}.csv', bytes);
      if (mounted) showStaffToast(context, l10n.staffExportReady(rows < 0 ? 0 : rows));
    } catch (e) {
      if (mounted) setState(() => _error = e is AppError && e.code == 'EXPORT_TOO_LARGE' ? l10n.staffExportTooMany : staffErrorText(l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final c = SaartheeColors.of(context);
    final wards = ref.watch(wardsListProvider).value?.wards ?? const [];
    return StaffPageScaffold(
      title: l10n.staffExportTitle,
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        children: [
          StaffCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  key: const Key('staff.export.dataset'),
                  initialValue: _dataset,
                  decoration: InputDecoration(labelText: l10n.staffExportDataset),
                  items: [
                    DropdownMenuItem(value: 'issues', child: Text(l10n.staffExportIssues)),
                    DropdownMenuItem(value: 'issue_events', child: Text(l10n.staffExportEvents)),
                    DropdownMenuItem(value: 'verifications', child: Text(l10n.staffExportVerifications)),
                  ],
                  onChanged: (v) => setState(() => _dataset = v ?? _dataset),
                ),
                const SizedBox(height: AppSpacing.s12),
                Wrap(spacing: AppSpacing.s8, children: [
                  OutlinedButton(onPressed: () => _pick(true), child: Text('${l10n.staffExportFrom}: ${Formatters.date(_from)}')),
                  OutlinedButton(onPressed: () => _pick(false), child: Text('${l10n.staffExportTo}: ${Formatters.date(_to)}')),
                ]),
                const SizedBox(height: AppSpacing.s12),
                DropdownButtonFormField<String?>(
                  initialValue: _ward,
                  decoration: InputDecoration(labelText: l10n.staffIssueWard),
                  items: [
                    DropdownMenuItem<String?>(value: null, child: Text(l10n.staffExportAllWards)),
                    for (final w in wards) DropdownMenuItem<String?>(value: w.id, child: Text(staffWardText(w, lang))),
                  ],
                  onChanged: (v) => setState(() => _ward = v),
                ),
                SwitchListTile(
                  key: const Key('staff.export.phone'),
                  contentPadding: EdgeInsets.zero,
                  value: _phone,
                  title: Text(l10n.staffExportPhone),
                  onChanged: (v) => setState(() => _phone = v),
                ),
                if (_phone) ...[
                  Text(l10n.staffExportPhoneWarning, key: const Key('staff.export.warning'), style: TextStyle(color: c.warning)),
                  TextField(key: const Key('staff.export.reason'), controller: _reason, maxLength: 200, decoration: InputDecoration(labelText: l10n.staffExportReason)),
                ],
                if (_error != null) InlineFieldError(key: const Key('staff.export.error'), message: _error!),
                const SizedBox(height: AppSpacing.s12),
                PrimaryButton(key: const Key('staff.export.download'), label: l10n.staffExportDownload, isLoading: _busy, onPressed: _download),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
