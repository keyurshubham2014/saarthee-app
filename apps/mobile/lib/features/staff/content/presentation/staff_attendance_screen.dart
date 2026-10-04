import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/app_error.dart';
import '../../../../core/api/error_messages.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/widgets.dart';
import '../data/staff_content_api.dart';
import 'staff_gate.dart';

final staffRsvpsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>(
      (ref, id) => ref.watch(staffContentApiProvider).rsvps(id),
    );

/// `/staff/initiatives/:id/attendance` (admin): RSVP list (display name or
/// "Resident", phone last 4), "Attended" checkboxes, "Save attendance"
/// (enabled after the start).
class StaffAttendanceScreen extends ConsumerStatefulWidget {
  const StaffAttendanceScreen({super.key, required this.id, this.startsAt});

  final String id;
  final DateTime? startsAt;

  @override
  ConsumerState<StaffAttendanceScreen> createState() =>
      _StaffAttendanceScreenState();
}

class _StaffAttendanceScreenState extends ConsumerState<StaffAttendanceScreen> {
  final Map<String, bool> _marks = {};
  bool _saving = false;

  Future<void> _save(List<Map<String, dynamic>> rows) async {
    final l10n = AppLocalizations.of(context);
    final api = ref.read(staffContentApiProvider);
    setState(() => _saving = true);
    try {
      bool was(String uid) =>
          rows.any((r) => r['userId'] == uid && r['status'] == 'attended');
      final on = _marks.entries
          .where((e) => e.value && !was(e.key))
          .map((e) => e.key)
          .toList();
      final off = _marks.entries
          .where((e) => !e.value && was(e.key))
          .map((e) => e.key)
          .toList();
      if (on.isNotEmpty) await api.markAttendance(widget.id, on, true);
      if (off.isNotEmpty) await api.markAttendance(widget.id, off, false);
      if (mounted) showSaartheeToast(context, l10n.staffContentSaved);
      ref.invalidate(staffRsvpsProvider(widget.id));
    } on AppError catch (e) {
      if (mounted) {
        showSaartheeToast(
          context,
          appErrorMessage(l10n, e),
          kind: ToastKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(staffRsvpsProvider(widget.id));
    final started =
        widget.startsAt == null || !widget.startsAt!.isAfter(DateTime.now());
    return StaffPage(
      title: l10n.staffContentAttendanceTitle,
      roles: adminOnly,
      child: async.when(
        loading: () => const SkeletonList(),
        error: (_, _) => ErrorState(
          message: l10n.staffContentLoadError,
          onRetry: () => ref.invalidate(staffRsvpsProvider(widget.id)),
        ),
        data: (rows) => rows.isEmpty
            ? EmptyState(message: l10n.staffContentNoRsvps)
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.gutter),
                children: [
                  if (!started) Text(l10n.staffContentAttendanceLocked),
                  for (final r in rows)
                    if (r['status'] != 'cancelled')
                      CheckboxListTile(
                        key: Key('staff.attendance.${r['userId']}'),
                        title: Text(str(r['displayName'])),
                        subtitle: r['phoneLast4'] == null
                            ? null
                            : Text(
                                l10n.staffContentPhoneLast4(
                                  '${r['phoneLast4']}',
                                ),
                              ),
                        value:
                            _marks['${r['userId']}'] ??
                            r['status'] == 'attended',
                        onChanged: started
                            ? (v) => setState(
                                () => _marks['${r['userId']}'] = v ?? false,
                              )
                            : null,
                      ),
                  const SizedBox(height: AppSpacing.s16),
                  PrimaryButton(
                    key: const Key('staff.attendance.save'),
                    label: l10n.staffContentSaveAttendance,
                    isLoading: _saving,
                    onPressed: started && _marks.isNotEmpty
                        ? () => _save(rows)
                        : null,
                  ),
                ],
              ),
      ),
    );
  }
}
