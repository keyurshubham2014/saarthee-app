import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/settings/locale_controller.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../shared/rep_shared.dart';
import '../shared/staff_widgets.dart';
import '../shell/staff_session.dart';
import '../ward_dashboard/rep_console_api.dart';
import '../ward_dashboard/ward_dashboard_models.dart';
import 'claim_dialogs.dart';
import 'staff_claims_screen.dart';

final staffClaimProvider = FutureProvider.autoDispose.family<Json, String>(
  (ref, id) => ref.watch(repConsoleApiProvider).claim(id),
);
final claimEvidenceProvider = FutureProvider.autoDispose
    .family<List<int>, (String, String)>(
      (ref, a) => ref.watch(repConsoleApiProvider).evidence(a.$1, a.$2),
    );

/// `/staff/claims/:id` (AC-3/4): evidence (admins only), claimant note,
/// representative record, phone-match line; Approve (method required) and
/// Reject (reason 5–300); moderators read only; Revoke on approved claims.
class StaffClaimDetailScreen extends ConsumerStatefulWidget {
  const StaffClaimDetailScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<StaffClaimDetailScreen> createState() => _State();
}

class _State extends ConsumerState<StaffClaimDetailScreen> {
  bool _busy = false;

  Future<void> _run(Future<Object?> Function() call, String done) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await call();
      ref.invalidate(staffClaimProvider(widget.id));
      ref.invalidate(staffClaimsProvider);
      if (mounted) showSaartheeToast(context, done);
    } catch (e) {
      if (mounted) {
        showSaartheeToast(
          context,
          repErrorMessage(l10n, e),
          kind: ToastKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final lang = ref.watch(localeProvider).languageCode;
    final admin = ref.watch(staffMeProvider).value?.isAdmin ?? false;
    final api = ref.read(repConsoleApiProvider);
    return StaffAsync<Json>(
      value: ref.watch(staffClaimProvider(widget.id)),
      onRetry: () => ref.invalidate(staffClaimProvider(widget.id)),
      builder: (cl) {
        final rec = cl['representativeRecord'] as Json? ?? const {};
        final pending = cl['status'] == 'pending';
        final evidence = (cl['evidence'] as List? ?? const []).cast<Json>();
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          children: [
            Text(
              '${rec[lang == 'gu' ? 'nameGu' : 'nameEn']}',
              style: text.titleLarge,
            ),
            const SizedBox(height: AppSpacing.s4),
            Wrap(
              spacing: AppSpacing.s8,
              children: [
                ClaimStatusChip(
                  status: '${cl['status']}',
                  reason: cl['rejectReason'] as String?,
                ),
                PhoneMatchChip(match: cl['phoneMatch'] == true),
              ],
            ),
            Text(
              l10n.repClaimPhoneLine(
                cl['phoneMatch'] == true ? l10n.repClaimYes : l10n.repClaimNo,
              ),
            ),
            Text(
              l10n.repClaimClaimant(
                '${(cl['claimant'] as Json?)?['displayName'] ?? '—'}',
              ),
            ),
            StaffSectionTitle(l10n.repClaimEvidenceAdminOnly),
            if (admin)
              Wrap(
                spacing: AppSpacing.s8,
                runSpacing: AppSpacing.s8,
                children: [
                  for (final e in evidence)
                    _EvidenceImage(
                      claimId: widget.id,
                      photoId: '${e['photoId']}',
                    ),
                ],
              ),
            if (cl['claimantNote'] != null) ...[
              StaffSectionTitle(l10n.repClaimNoteRow),
              Text(jsonText(cl, 'claimantNote')),
            ],
            StaffSectionTitle(l10n.repClaimRecordTitle),
            Text(
              l10n.repClaimTerm(
                '${rec['termStart'] ?? '—'}',
                '${rec['termEnd'] ?? '—'}',
              ),
            ),
            Text(
              '${l10n.repClaimSource}: ${rec['sourceUrl'] ?? ''}',
              style: text.bodySmall,
            ),
            const SizedBox(height: AppSpacing.s24),
            if (!admin)
              Text(
                l10n.repClaimModeratorReadOnly,
                key: const Key('claim.readOnly'),
              )
            else if (pending) ...[
              PrimaryButton(
                key: const Key('claim.approve'),
                label: l10n.repClaimApprove,
                onPressed: _busy
                    ? null
                    : () async {
                        final m = await showApproveDialog(context);
                        if (m != null) {
                          await _run(
                            () => api.approve(widget.id, m),
                            l10n.repClaimDecided,
                          );
                        }
                      },
              ),
              const SizedBox(height: AppSpacing.s8),
              SecondaryButton(
                key: const Key('claim.reject'),
                label: l10n.repClaimReject,
                onPressed: _busy
                    ? null
                    : () async {
                        final r = await showReasonDialog(
                          context,
                          l10n.repClaimRejectTitle,
                          l10n.repClaimReject,
                        );
                        if (r != null) {
                          await _run(
                            () => api.reject(widget.id, r),
                            l10n.repClaimDecided,
                          );
                        }
                      },
              ),
            ] else if (cl['status'] == 'approved' && rec['verified'] == true)
              SecondaryButton(
                key: const Key('claim.revoke'),
                label: l10n.repClaimRevoke,
                onPressed: _busy
                    ? null
                    : () async {
                        final r = await showReasonDialog(
                          context,
                          l10n.repClaimRevoke,
                          l10n.repClaimRevoke,
                        );
                        if (r != null) {
                          await _run(
                            () => api.revoke('${rec['id']}', r),
                            l10n.repClaimRevoked,
                          );
                        }
                      },
              ),
          ],
        );
      },
    );
  }
}

class _EvidenceImage extends ConsumerWidget {
  const _EvidenceImage({required this.claimId, required this.photoId});

  final String claimId;
  final String photoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(claimEvidenceProvider((claimId, photoId))).value;
    return ClipRRect(
      borderRadius: AppRadii.controlRadius,
      child: SizedBox(
        width: 160,
        height: 160,
        child: bytes == null || bytes.isEmpty
            ? const SizedBox.shrink()
            : InteractiveViewer(
                child: Image.memory(
                  Uint8List.fromList(bytes),
                  fit: BoxFit.cover,
                ),
              ),
      ),
    );
  }
}
