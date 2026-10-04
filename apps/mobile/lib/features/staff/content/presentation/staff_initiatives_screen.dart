import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/app_error.dart';
import '../../../../core/api/error_messages.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/icons.dart';
import '../../../../core/widgets/widgets.dart';
import '../application/content_validators.dart';
import '../data/staff_content_api.dart';
import 'staff_gate.dart';

final staffInitiativesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>(
      (ref) => ref.watch(staffContentApiProvider).initiatives(),
    );

String staffStatusLabel(AppLocalizations l10n, Object? status) =>
    switch (status) {
      'published' => l10n.staffContentStatusPublished,
      'cancelled' => l10n.staffContentStatusCancelled,
      'completed' => l10n.staffContentStatusCompleted,
      _ => l10n.staffContentStatusDraft,
    };

/// `/staff/initiatives` (admin): list by date with status actions Publish /
/// Cancel / Complete, Edit and Attendance.
class StaffInitiativesScreen extends ConsumerWidget {
  const StaffInitiativesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(staffInitiativesProvider);
    final api = ref.read(staffContentApiProvider);

    Future<void> setStatus(String id, String status) async {
      try {
        await api.updateInitiative(id, {'status': status});
      } on AppError catch (e) {
        if (context.mounted) {
          showSaartheeToast(
            context,
            appErrorMessage(l10n, e),
            kind: ToastKind.error,
          );
        }
      }
      ref.invalidate(staffInitiativesProvider);
    }

    return StaffPage(
      title: l10n.staffContentInitiativesTitle,
      roles: adminOnly,
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('staff.initiatives.new'),
        onPressed: () => context.push('/staff/initiatives/new'),
        icon: const Icon(SaartheeIcons.add),
        label: Text(l10n.staffContentNewInitiative),
      ),
      child: async.when(
        loading: () => const SkeletonList(),
        error: (_, _) => ErrorState(
          message: l10n.staffContentLoadError,
          onRetry: () => ref.invalidate(staffInitiativesProvider),
        ),
        data: (rows) => ListView.separated(
          itemCount: rows.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final r = rows[i];
            final id = '${r['id']}';
            final status = '${r['status']}';
            return ListTile(
              key: Key('staff.initiative.$id'),
              title: Text(str(r['titleEn'])),
              subtitle: Text(
                '${staffStatusLabel(l10n, status)} · ${isoToIstInput('${r['startsAt']}')} · ${l10n.initiativesGoing((r['goingCount'] as num?)?.toInt() ?? 0)}',
              ),
              trailing: Wrap(
                children: [
                  if (status == 'draft')
                    TextButton(
                      onPressed: () => setStatus(id, 'published'),
                      child: Text(l10n.staffContentPublish),
                    ),
                  if (status == 'published')
                    TextButton(
                      onPressed: () => setStatus(id, 'completed'),
                      child: Text(l10n.staffContentComplete),
                    ),
                  if (status != 'cancelled')
                    TextButton(
                      onPressed: () => setStatus(id, 'cancelled'),
                      child: Text(l10n.staffContentCancelDrive),
                    ),
                  IconButton(
                    tooltip: l10n.staffContentAttendanceTitle,
                    icon: const Icon(SaartheeIcons.factCheck),
                    onPressed: () => context.push(
                      '/staff/initiatives/$id/attendance',
                      extra: r,
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.staffContentEdit,
                    icon: const Icon(SaartheeIcons.editNote),
                    onPressed: () =>
                        context.push('/staff/initiatives/$id', extra: r),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
