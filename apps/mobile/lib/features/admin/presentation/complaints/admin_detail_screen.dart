import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/widgets.dart' as core;
import '../../application/admin_complaints.dart';
import '../../data/admin_api_error.dart';
import '../../data/models/complaint_detail.dart';
import '../../data/models/complaint_summary.dart';
import '../admin_format.dart';
import '../admin_l10n.dart';
import '../admin_paths.dart';
import '../due/reminder_sheet.dart';
import '../shell/admin_session_guard.dart';
import '../widgets/admin_tokens.dart';
import '../widgets/admin_widgets.dart';

core.ComplaintStatus _coreStatus(ComplaintStatus s) => switch (s) {
  ComplaintStatus.filed => core.ComplaintStatus.filed,
  ComplaintStatus.reminded => core.ComplaintStatus.waiting,
  ComplaintStatus.verifiedFixed => core.ComplaintStatus.fixed,
  ComplaintStatus.verifiedNotFixed => core.ComplaintStatus.notFixed,
};

/// `/admin/complaints/:id` (02 §4.20).
class AdminDetailScreen extends ConsumerWidget {
  const AdminDetailScreen({super.key, required this.complaintId});
  final String complaintId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = adminL10n(context);
    final detail = ref.watch(complaintDetailProvider(complaintId));
    final busy = ref.watch(complaintActionsProvider(complaintId));

    Widget body;
    Widget? bottom;
    if (detail.hasValue) {
      final d = detail.requireValue;
      body = RefreshIndicator(
        onRefresh: () =>
            ref.refresh(complaintDetailProvider(complaintId).future),
        child: _DetailBody(detail: d, busy: busy),
      );
      bottom = _ActionBar(detail: d, busy: busy);
    } else if (detail.hasError) {
      final error = asAdminError(detail.error!);
      body = error.code == AdminErrorCodes.notFound
          ? AdminEmptyState(
              icon: Icons.search_off_rounded,
              message: l10n.adminDetailNotFound,
              actionLabel: l10n.adminBack,
              onAction: () => context.canPop()
                  ? context.pop()
                  : context.go(AdminPaths.complaints),
            )
          : AdminErrorView(
              title: l10n.adminDetailLoadFailed,
              error: error,
              onRetry: () =>
                  ref.invalidate(complaintDetailProvider(complaintId)),
            );
      body = Center(child: SingleChildScrollView(child: body));
    } else {
      body = const AdminSkeletonList(count: 3, height: 180);
    }

    return AdminSessionGuard(
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.adminDetailTitle),
          actions: <Widget>[
            if (detail.hasValue && !detail.requireValue.isAnonymized)
              PopupMenuButton<String>(
                key: const Key('adminDetailOverflow'),
                tooltip: l10n.adminMoreActions,
                enabled: busy == null,
                onSelected: (_) =>
                    _confirmAnonymize(context, ref, detail.requireValue),
                itemBuilder: (_) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    key: const Key('adminRemovePersonalData'),
                    value: 'anonymize',
                    child: Text(l10n.adminRemovePersonalData),
                  ),
                ],
              ),
          ],
        ),
        body: SafeArea(child: AdminContentWidth(child: body)),
        bottomNavigationBar: bottom,
      ),
    );
  }
}

Future<void> _runAction(
  BuildContext context,
  Future<void> Function() action,
  String success,
) async {
  final l10n = adminL10n(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(success)));
  } on AdminApiError catch (e) {
    if (e.isSessionEnded) {
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(adminErrorMessage(l10n, e))));
  }
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
}) async {
  final l10n = adminL10n(context);
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: <Widget>[
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.adminCancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<void> _confirmAnonymize(
  BuildContext context,
  WidgetRef ref,
  ComplaintDetail d,
) async {
  final l10n = adminL10n(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => _AnonymizeDialog(ccrsNumber: d.summary.ccrsNumber),
  );
  if (ok != true || !context.mounted) {
    return;
  }
  await _runAction(
    context,
    () => ref.read(complaintActionsProvider(d.id).notifier).anonymize(),
    l10n.adminPersonalDataRemoved,
  );
}

class _AnonymizeDialog extends StatefulWidget {
  const _AnonymizeDialog({required this.ccrsNumber});
  final String ccrsNumber;

  @override
  State<_AnonymizeDialog> createState() => _AnonymizeDialogState();
}

class _AnonymizeDialogState extends State<_AnonymizeDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = adminL10n(context);
    final matches = _controller.text.trim() == widget.ccrsNumber.trim();
    return AlertDialog(
      title: Text(l10n.adminAnonymizeTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(l10n.adminAnonymizeBody),
            const SizedBox(height: 16),
            TextField(
              key: const Key('adminAnonymizeInput'),
              controller: _controller,
              autocorrect: false,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l10n.adminAnonymizeTypeLabel(widget.ccrsNumber),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.adminCancel),
        ),
        FilledButton(
          key: const Key('adminAnonymizeConfirm'),
          style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: matches ? () => Navigator.of(context).pop(true) : null,
          child: Text(l10n.adminRemovePersonalData),
        ),
      ],
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.detail, required this.busy});
  final ComplaintDetail detail;
  final String? busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = adminL10n(context);
    final theme = Theme.of(context);
    final tokens = AdminTokens.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final d = detail;
    final s = d.summary;
    final latest = d.latestVerification;

    ImageProvider? photoOf(AsyncValue<dynamic> value) =>
        value.hasValue ? MemoryImage(value.requireValue) : null;
    final before = d.isAnonymized || !d.hasPhoto
        ? null
        : photoOf(ref.watch(adminReportPhotoProvider(d.id)));
    final after = latest == null || !latest.hasPhoto || d.isAnonymized
        ? null
        : photoOf(ref.watch(adminVerificationPhotoProvider(latest.id)));

    Widget fact(String label, String value, {Widget? trailing, Key? key}) =>
        ListTile(
          key: key,
          contentPadding: EdgeInsets.zero,
          minTileHeight: 48,
          title: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(color: tokens.inkMuted),
          ),
          subtitle: Text(value, style: theme.textTheme.bodyLarge),
          trailing: trailing,
        );

    final gps = d.latitude != null && d.longitude != null
        ? l10n.adminGpsValue(
            d.latitude!.toStringAsFixed(5),
            d.longitude!.toStringAsFixed(5),
            d.gpsAccuracyM == null
                ? '?'
                : formatMeters(d.gpsAccuracyM!, locale),
          )
        : l10n.adminNotRecorded;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: adminScreenPadding,
      children: <Widget>[
        core.BeforeAfterCard(
          before: before,
          after: after,
          beforeDate: s.createdAt,
          afterDate: latest?.createdAt,
          status: _coreStatus(s.status),
          beforeOnly: latest == null,
        ),
        if (d.isAnonymized) ...<Widget>[
          const SizedBox(height: 8),
          Text(l10n.adminErrorPhotoDeleted, style: theme.textTheme.bodyMedium),
        ],
        if (latest != null && latest.sameImageAsReport) ...<Widget>[
          const SizedBox(height: 8),
          AdminMessageBanner(
            message: l10n.adminSameImageWarning,
            icon: Icons.warning_amber_rounded,
          ),
        ],
        if (latest != null &&
            latest.distanceWarning &&
            latest.distanceFromReportM != null) ...<Widget>[
          const SizedBox(height: 8),
          AdminMessageBanner(
            message: l10n.adminDistanceWarning(
              formatMeters(latest.distanceFromReportM!, locale),
            ),
            icon: Icons.location_off_rounded,
          ),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: <Widget>[
            AdminStatusChip(status: s.status),
            if (s.isExcluded)
              AdminTag(
                icon: Icons.block_rounded,
                label: s.exclusionReason == null
                    ? l10n.adminTagExcluded
                    : l10n.adminExcludedBecause(
                        exclusionReasonLabel(l10n, s.exclusionReason!),
                      ),
                background: tokens.notFixedTint,
                foreground: tokens.ink,
              ),
            if (d.isAnonymized)
              AdminTag(
                icon: Icons.person_off_rounded,
                label: l10n.adminTagAnonymized,
                background: tokens.neutralTint,
                foreground: tokens.ink,
              ),
          ],
        ),
        if (s.isExcluded && d.exclusionNote != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(d.exclusionNote!, style: theme.textTheme.bodyMedium),
          ),
        const SizedBox(height: 8),
        fact(
          l10n.adminFactCcrs,
          s.ccrsNumber,
          trailing: s.ccrsDuplicate
              ? AdminTag(
                  icon: Icons.content_copy_rounded,
                  label: l10n.adminTagDuplicate,
                  background: tokens.waitingTint,
                  foreground: tokens.ink,
                )
              : null,
        ),
        fact(l10n.adminFactCategory, s.categoryName),
        fact(
          l10n.adminFactSource,
          '${sourceLabel(l10n, s.sourceTag)} · ${s.groupLabel ?? l10n.adminNoGroup}',
        ),
        fact(l10n.adminFactFiled, formatIstDateTime(s.createdAt, locale)),
        fact(
          l10n.adminFactCaptured,
          d.deviceCapturedAt == null
              ? l10n.adminNotRecorded
              : formatIstDateTime(d.deviceCapturedAt!, locale),
        ),
        fact(l10n.adminFactGps, gps),
        if (d.phoneE164 == null || d.isAnonymized)
          fact(l10n.adminFactPhone, l10n.adminPhoneRemoved)
        else
          ListTile(
            key: const Key('adminDetailPhone'),
            contentPadding: EdgeInsets.zero,
            minTileHeight: 48,
            title: Text(
              l10n.adminFactPhone,
              style: theme.textTheme.bodySmall?.copyWith(
                color: tokens.inkMuted,
              ),
            ),
            subtitle: Text(
              formatPhone(d.phoneE164!),
              style: theme.textTheme.bodyLarge,
            ),
            trailing: Tooltip(
              message: l10n.adminTapToCopy,
              child: const Icon(Icons.copy_rounded),
            ),
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: d.phoneE164!));
              if (context.mounted) {
                showAdminSnack(context, l10n.adminCopied);
              }
            },
          ),
        const Divider(height: 32),
        Text(l10n.adminRemindersTitle, style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        if (d.reminders.isEmpty)
          Text(l10n.adminNoReminders, style: theme.textTheme.bodyMedium),
        for (final r in d.reminders)
          ListTile(
            key: Key('adminReminder-${r.id}'),
            contentPadding: EdgeInsets.zero,
            minTileHeight: 56,
            leading: Icon(
              r.isActive ? Icons.send_rounded : Icons.link_off_rounded,
            ),
            title: Text(
              r.sentBy == null
                  ? l10n.adminReminderSent(formatIstDateTime(r.sentAt, locale))
                  : l10n.adminReminderSentBy(
                      formatIstDateTime(r.sentAt, locale),
                      r.sentBy!,
                    ),
            ),
            subtitle: r.revokedAt == null
                ? null
                : Text(
                    l10n.adminRevokedAt(
                      formatIstDateTime(r.revokedAt!, locale),
                    ),
                  ),
            trailing: r.isActive && !d.isAnonymized
                ? TextButton(
                    key: Key('adminRevoke-${r.id}'),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: busy != null
                        ? null
                        : () async {
                            final ok = await _confirm(
                              context,
                              title: l10n.adminRevokeTitle,
                              body: l10n.adminRevokeBody,
                              confirmLabel: l10n.adminRevoke,
                            );
                            if (!ok || !context.mounted) {
                              return;
                            }
                            await _runAction(
                              context,
                              () => ref
                                  .read(complaintActionsProvider(d.id).notifier)
                                  .revokeReminder(r.id),
                              l10n.adminReminderRevoked,
                            );
                          },
                    child: busy == 'revoke:${r.id}'
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.adminRevoke),
                  )
                : null,
          ),
        const Divider(height: 32),
        Text(l10n.adminVerificationsTitle, style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        if (d.verifications.isEmpty)
          Text(l10n.adminNoVerifications, style: theme.textTheme.bodyMedium),
        for (final v in d.verifications)
          Padding(
            key: Key('adminVerification-${v.id}'),
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (v.hasPhoto && !d.isAnonymized)
                  GestureDetector(
                    onTap: () => _showPhoto(context, v.id),
                    child: AdminPhoto(
                      size: 72,
                      provider: adminVerificationPhotoProvider(v.id),
                      semanticLabel: l10n.adminPhotoAfterSemantics,
                    ),
                  )
                else
                  AdminPhotoPlaceholder(
                    size: 72,
                    label: d.isAnonymized
                        ? l10n.adminErrorPhotoDeleted
                        : l10n.adminPhotoUnavailable,
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      AdminStatusChip(
                        status: v.isFixed
                            ? ComplaintStatus.verifiedFixed
                            : ComplaintStatus.verifiedNotFixed,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.adminVerificationTime(
                          formatIstDateTime(v.createdAt, locale),
                        ),
                        style: theme.textTheme.bodyMedium,
                      ),
                      if (v.note != null)
                        Text(
                          l10n.adminVerificationNote(v.note!),
                          style: theme.textTheme.bodyMedium,
                        ),
                      if (v.distanceFromReportM != null)
                        Text(
                          l10n.adminVerificationDistance(
                            formatMeters(v.distanceFromReportM!, locale),
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: v.distanceWarning
                                ? tokens.notFixed
                                : tokens.inkMuted,
                          ),
                        ),
                      if (v.sameImageAsReport)
                        Text(
                          l10n.adminSameImageWarning,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: tokens.notFixed,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  void _showPhoto(BuildContext context, String verificationId) {
    final l10n = adminL10n(context);
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AdminPhoto(
              aspectRatio: 3 / 4,
              provider: adminVerificationPhotoProvider(verificationId),
              semanticLabel: l10n.adminPhotoAfterSemantics,
            ),
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.adminClose),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionBar extends ConsumerWidget {
  const _ActionBar({required this.detail, required this.busy});
  final ComplaintDetail detail;
  final String? busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = adminL10n(context);
    final theme = Theme.of(context);
    final d = detail;
    final s = d.summary;
    final sending = ref.watch(reminderSenderProvider).contains(d.id);
    final reminderBlocked = s.isExcluded || d.isAnonymized;
    final actions = ref.read(complaintActionsProvider(d.id).notifier);

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (reminderBlocked)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  d.isAnonymized
                      ? l10n.adminReminderOffAnonymized
                      : l10n.adminReminderOffExcluded,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            Row(
              children: <Widget>[
                Expanded(
                  child: AdminPrimaryButton(
                    key: const Key('adminDetailSendReminder'),
                    icon: Icons.send_rounded,
                    label: l10n.adminSendReminder,
                    busy: sending,
                    onPressed: reminderBlocked || busy != null
                        ? null
                        : () => sendReminderFlow(context, ref, d.id),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AdminSecondaryButton(
                    key: Key(
                      s.isExcluded ? 'adminIncludeAgain' : 'adminExclude',
                    ),
                    label: s.isExcluded
                        ? l10n.adminIncludeAgain
                        : l10n.adminExclude,
                    busy: busy == 'exclude' || busy == 'include',
                    onPressed: busy != null
                        ? null
                        : () async {
                            if (s.isExcluded) {
                              final ok = await _confirm(
                                context,
                                title: l10n.adminIncludeTitle,
                                body: l10n.adminIncludeBody,
                                confirmLabel: l10n.adminIncludeAgain,
                              );
                              if (!ok || !context.mounted) {
                                return;
                              }
                              await _runAction(
                                context,
                                actions.includeAgain,
                                l10n.adminIncludedAgainDone,
                              );
                            } else {
                              final input =
                                  await showModalBottomSheet<
                                    ({String reason, String note})
                                  >(
                                    context: context,
                                    isScrollControlled: true,
                                    showDragHandle: true,
                                    useSafeArea: true,
                                    builder: (_) => const _ExcludeSheet(),
                                  );
                              if (input == null || !context.mounted) {
                                return;
                              }
                              await _runAction(
                                context,
                                () => actions.exclude(
                                  reason: input.reason,
                                  note: input.note,
                                ),
                                l10n.adminExcludedDone,
                              );
                            }
                          },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExcludeSheet extends StatefulWidget {
  const _ExcludeSheet();

  @override
  State<_ExcludeSheet> createState() => _ExcludeSheetState();
}

class _ExcludeSheetState extends State<_ExcludeSheet> {
  static const _reasons = <String>['test', 'invalid', 'duplicate', 'other'];
  String? _reason;
  bool _showReasonError = false;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = adminL10n(context);
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              l10n.adminExcludeSheetTitle,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.adminExcludeReasonLabel,
              style: theme.textTheme.labelLarge,
            ),
            RadioGroup<String>(
              groupValue: _reason,
              onChanged: (v) => setState(() {
                _reason = v;
                _showReasonError = false;
              }),
              child: Column(
                children: <Widget>[
                  for (final r in _reasons)
                    RadioListTile<String>(
                      key: Key('adminExcludeReason-$r'),
                      contentPadding: EdgeInsets.zero,
                      value: r,
                      title: Text(exclusionReasonLabel(l10n, r)),
                    ),
                ],
              ),
            ),
            if (_showReasonError)
              AdminMessageBanner(message: l10n.adminChooseReason),
            const SizedBox(height: 12),
            TextField(
              key: const Key('adminExcludeNote'),
              controller: _note,
              maxLength: 500,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: l10n.adminExcludeNoteLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            AdminPrimaryButton(
              key: const Key('adminExcludeConfirm'),
              label: l10n.adminExclude,
              onPressed: () {
                if (_reason == null) {
                  setState(() => _showReasonError = true);
                  return;
                }
                Navigator.of(context).pop((reason: _reason!, note: _note.text));
              },
            ),
          ],
        ),
      ),
    );
  }
}
