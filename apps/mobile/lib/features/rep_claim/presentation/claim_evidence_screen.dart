import 'package:flutter/material.dart' hide ErrorSummary;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../application/claim_draft.dart';

/// `/representatives/:id/claim` — step 1 of 2 (TASK-11 §5.4): 1–3 evidence
/// photos (camera or gallery) uploaded as private `rep_evidence`, retry on
/// failure, optional note; the draft stays in memory while offline.
class ClaimEvidenceScreen extends ConsumerStatefulWidget {
  const ClaimEvidenceScreen({super.key, required this.repId});

  final String repId;

  @override
  ConsumerState<ClaimEvidenceScreen> createState() => _State();
}

class _State extends ConsumerState<ClaimEvidenceScreen> {
  late final _note = TextEditingController(
    text: ref.read(claimDraftProvider(widget.repId)).note,
  );
  bool _showError = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _add({required bool camera}) async {
    final path = await ref.read(claimPhotoPickerProvider).pick(camera: camera);
    if (path == null) return;
    setState(() => _showError = false);
    await ref.read(claimDraftProvider(widget.repId).notifier).add(path);
  }

  void _continue() {
    final draft = ref.read(claimDraftProvider(widget.repId));
    if (!draft.ready) {
      setState(() => _showError = true);
      return;
    }
    context.push('/representatives/${widget.repId}/claim/check');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final draft = ref.watch(claimDraftProvider(widget.repId));
    final ctl = ref.read(claimDraftProvider(widget.repId).notifier);
    final offline = ref.watch(isOfflineProvider);
    final full = draft.photos.length >= ClaimDraftController.maxPhotos;
    return Scaffold(
      appBar: SaartheeAppBar(title: l10n.repClaimTitle),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        children: [
          if (offline) ...[
            NoticeBanner(
              key: const Key('repClaim.offline'),
              kind: NoticeKind.offline,
              message: l10n.repClaimOffline,
              rounded: true,
            ),
            const SizedBox(height: AppSpacing.s12),
          ],
          Text(l10n.repClaimStep(1, 2), style: text.labelLarge),
          const SizedBox(height: AppSpacing.s8),
          Text(l10n.repClaimBody, style: text.bodyLarge),
          const SizedBox(height: AppSpacing.s16),
          if (_showError) ...[
            ErrorSummary(
              key: const Key('repClaim.errorSummary'),
              items: [ErrorSummaryItem(l10n.repClaimEvidenceRequired)],
            ),
            const SizedBox(height: AppSpacing.s12),
          ],
          for (final p in draft.photos)
            ListRow(
              key: Key('repClaim.photo.${p.path}'),
              leading: Icon(switch (p.state) {
                EvidenceState.done => SaartheeIcons.check,
                EvidenceState.failed => SaartheeIcons.errorOutline,
                EvidenceState.uploading => SaartheeIcons.hourglass,
              }),
              title: switch (p.state) {
                EvidenceState.done => l10n.repClaimEvidenceRow,
                EvidenceState.failed => l10n.repClaimUploadFailed,
                EvidenceState.uploading => l10n.repClaimUploading,
              },
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (p.state == EvidenceState.failed)
                    TextButton(
                      key: const Key('repClaim.retry'),
                      onPressed: () => ctl.retry(p.path),
                      child: Text(l10n.repClaimRetry),
                    ),
                  IconButton(
                    tooltip: l10n.repClaimRemovePhoto,
                    icon: const Icon(SaartheeIcons.delete),
                    onPressed: () => ctl.remove(p.path),
                  ),
                ],
              ),
              showChevron: false,
            ),
          Text(
            l10n.repClaimPhotoCount(draft.photos.length),
            style: text.bodySmall,
          ),
          const SizedBox(height: AppSpacing.s8),
          SecondaryButton(
            key: const Key('repClaim.camera'),
            label: l10n.repClaimAddCamera,
            icon: SaartheeIcons.camera,
            onPressed: full ? null : () => _add(camera: true),
          ),
          const SizedBox(height: AppSpacing.s8),
          SecondaryButton(
            key: const Key('repClaim.gallery'),
            label: l10n.repClaimAddGallery,
            icon: SaartheeIcons.image,
            onPressed: full ? null : () => _add(camera: false),
          ),
          const SizedBox(height: AppSpacing.s16),
          LabeledTextField(
            fieldKey: const Key('repClaim.note'),
            label: l10n.repClaimNoteRow,
            optional: true,
            controller: _note,
            maxLines: 3,
            onChanged: ctl.setNote,
          ),
          const SizedBox(height: AppSpacing.s24),
          PrimaryButton(
            key: const Key('repClaim.continue'),
            label: l10n.repClaimContinue,
            onPressed: _continue,
          ),
        ],
      ),
    );
  }
}
