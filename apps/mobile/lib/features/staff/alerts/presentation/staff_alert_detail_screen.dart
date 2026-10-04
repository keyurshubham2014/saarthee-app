import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/app_error.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/settings/locale_controller.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/alerts/validity_format.dart';
import '../../../../core/widgets/widgets.dart';
import '../../shared/staff_shared.dart';
import '../application/staff_alerts_providers.dart';
import '../data/staff_alerts_api.dart';
import 'composer_preview.dart';

/// `/staff/alerts/:id` (REQ-F-036): preview in both languages, approval
/// panel, actions by state with confirm dialogs (publish, retract).
class StaffAlertDetailScreen extends ConsumerStatefulWidget {
  const StaffAlertDetailScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<StaffAlertDetailScreen> createState() => _State();
}

class _State extends ConsumerState<StaffAlertDetailScreen> {
  bool _busy = false;

  Future<void> _act(String action, {Map<String, dynamic>? body}) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final res = await ref
          .read(staffAlertsApiProvider)
          .action(widget.id, action, body: body);
      if (!mounted) return;
      if (action == 'supersede') {
        context.pushReplacement('/staff/alerts/${res['id']}');
      } else {
        ref.invalidate(staffAlertProvider(widget.id));
        showSaartheeToast(context, l10n.staffAlertsDone);
      }
    } catch (e) {
      if (mounted) {
        final err = AppError.from(e);
        showSaartheeToast(
          context,
          l10n.staffAlertsActionError(
            err.message.isEmpty ? err.code : err.message,
          ),
          kind: ToastKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String message, {TextEditingController? reason}) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: reason == null
            ? Text(message)
            : TextField(
                controller: reason,
                decoration: InputDecoration(labelText: message),
                maxLength: 200,
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(l10n.staffAlertsCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(l10n.staffAlertsConfirm),
          ),
        ],
      ),
    );
    return ok == true;
  }

  bool _quiet(StaffAlert a) {
    final h = toIst(DateTime.now()).hour;
    return a.severity.name != 'critical' && (h >= 22 || h < 7);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    final role = ref.watch(staffRoleProvider);
    return StaffPageScaffold(
      title: l10n.staffAlertsTitle,
      body: ref
          .watch(staffAlertProvider(widget.id))
          .when(
            loading: () => const SkeletonList(count: 4),
            error: (_, _) => ErrorState(
              message: l10n.staffAlertsLoadError,
              onRetry: () => ref.invalidate(staffAlertProvider(widget.id)),
            ),
            data: (a) {
              final needed = a.approvalsNeeded - a.approvals.length;
              final twoPerson = a.approvalsNeeded == 2;
              final area = a.scope == 'city'
                  ? l10n.alertsAreaCity
                  : a.scope == 'zone'
                  ? l10n.staffAlertsAreaZone
                  : l10n.alertsAreaWards('${a.wardIds.length}');
              Widget button(
                String key,
                String label,
                Future<void> Function() onTap,
              ) => Padding(
                padding: const EdgeInsets.only(top: AppSpacing.s8),
                child: OutlinedButton(
                  key: ValueKey(key),
                  onPressed: _busy ? null : onTap,
                  child: Text(label),
                ),
              );
              return ListView(
                padding: const EdgeInsets.all(AppSpacing.gutter),
                children: [
                  ComposerPreview(draft: ComposerDraft.from(a)),
                  const SizedBox(height: AppSpacing.s16),
                  for (final ap in a.approvals)
                    Text(
                      l10n.staffAlertsApprovedBy(
                        ap.name ?? ap.actorId.substring(0, 8),
                        ap.role == 'admin'
                            ? l10n.staffAlertsRoleAdmin
                            : l10n.staffAlertsRoleModerator,
                      ),
                    ),
                  if (a.status == 'pending_approval' && needed > 0)
                    Text(
                      key: const ValueKey('approvalsNeeded'),
                      twoPerson && a.approvals.length == 1
                          ? l10n.staffAlertsNeedsAdmin
                          : l10n.staffAlertsNeedsMore(needed),
                    ),
                  if (!a.editable && a.status != 'published')
                    Text(l10n.staffAlertsReadOnly),
                  if (a.editable)
                    button(
                      'staffEdit',
                      l10n.staffAlertsSaveDraft,
                      () async => context.push('/staff/alerts/${a.id}/edit'),
                    ),
                  if (a.status == 'draft')
                    button(
                      'staffSubmit',
                      l10n.staffAlertsSubmit,
                      () => _act('submit'),
                    ),
                  if (a.status == 'pending_approval' && needed > 0)
                    button(
                      'staffApprove',
                      l10n.staffAlertsApprove,
                      () => _act('approve'),
                    ),
                  if (a.status == 'pending_approval' &&
                      needed <= 0 &&
                      (!twoPerson || role == 'admin'))
                    button('staffPublish', l10n.staffAlertsPublish, () async {
                      final msg = _quiet(a)
                          ? l10n.staffAlertsConfirmPublishQuiet(area)
                          : l10n.staffAlertsConfirmPublish(area);
                      if (await _confirm(msg)) await _act('publish');
                    }),
                  if (a.status == 'published') ...[
                    button('staffRetract', l10n.staffAlertsRetract, () async {
                      final reason = TextEditingController();
                      if (await _confirm(
                        l10n.staffAlertsRetractReason,
                        reason: reason,
                      )) {
                        await _act(
                          'retract',
                          body: {'reason': reason.text.trim()},
                        );
                      }
                      reason.dispose();
                    }),
                    button(
                      'staffUpdate',
                      l10n.staffAlertsUpdate,
                      () => _act('supersede'),
                    ),
                  ],
                  Text(
                    formatAlertValidity(l10n, lang, a.validFrom, a.validTo),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              );
            },
          ),
    );
  }
}
