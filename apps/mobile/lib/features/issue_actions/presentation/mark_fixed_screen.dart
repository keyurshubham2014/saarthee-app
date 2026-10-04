import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/app_error.dart';
import '../../../core/capture/evidence_capture.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../application/issue_providers.dart';
import '../application/photo_prep.dart';
import '../data/issue_actions_api.dart';
import 'common.dart';
import 'motion/send_progress_button.dart';

/// `/issues/:id/mark-fixed` (TASK-06 §5.4, REQ-F-021): up to 3 optional
/// "after" photos (blurred like report photos), optional note, primary
/// "Mark as fixed" with in-button progress.
class MarkFixedScreen extends ConsumerStatefulWidget {
  const MarkFixedScreen({super.key, required this.issueId});

  final String issueId;

  @override
  ConsumerState<MarkFixedScreen> createState() => _MarkFixedScreenState();
}

class _MarkFixedScreenState extends ConsumerState<MarkFixedScreen> {
  static const int _maxPhotos = 3;
  final _note = TextEditingController();
  final List<String> _paths = [];
  final Map<String, String> _uploaded = {};
  final String _actionId = newActionId();
  bool _sending = false;
  bool _stale = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    final photo = await ref.read(evidenceCaptureProvider).takePhoto();
    if (photo == null || !mounted) return;
    setState(() => _paths.add(photo.path));
  }

  Future<void> _submit(String expectedStatus) async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _sending = true;
      _error = null;
      _stale = false;
    });
    try {
      final uploader = ref.read(issuePhotoUploaderProvider);
      for (final p in _paths) {
        _uploaded[p] ??= await uploader.upload(widget.issueId, p, 'after');
      }
      await ref
          .read(issueActionsApiProvider)
          .changeStatus(
            widget.issueId,
            to: 'marked_fixed',
            expectedStatus: expectedStatus,
            clientActionId: _actionId,
            note: _note.text,
            photoIds: [for (final p in _paths) _uploaded[p]!],
          );
      if (!mounted) return;
      refreshIssue(ref, widget.issueId);
      showSaartheeToast(context, l10n.issueActionsMarkFixedDone);
      context.pop();
    } on AppError catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _stale = e.code == 'STALE_STATUS';
        _error = lifecycleErrorMessage(l10n, e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final issue = ref.watch(issueLifecycleProvider(widget.issueId));
    final current = issue.value;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.issueActionsMarkFixedTitle)),
      body: PinnedBottomLayout(
        bottom: [
          SizedBox(
            width: double.infinity,
            child: SendProgressButton(
              key: const Key('markFixed.submit'),
              label: l10n.issueActionsMarkFixedTitle,
              sending: _sending,
              onPressed: current == null || !current.actions.markFixed
                  ? null
                  : () => _submit(current.apiStatus),
            ),
          ),
        ],
        children: [
          Text(l10n.issueActionsMarkFixedHelper, style: text.bodyLarge),
          const SizedBox(height: AppSpacing.s16),
          Text(l10n.issueActionsMarkFixedAddPhoto, style: text.titleSmall),
          const SizedBox(height: AppSpacing.s8),
          for (final p in _paths)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s8),
              child: Row(
                children: [
                  SizedBox(
                    width: 96,
                    child: PhotoThumb(
                      image: FileImage(File(p)),
                      semanticLabel: l10n.issueActionsVerifyAfter,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: l10n.issueActionsRemovePhoto,
                    onPressed: _sending
                        ? null
                        : () => setState(() => _paths.remove(p)),
                    icon: const Icon(SaartheeIcons.close),
                  ),
                ],
              ),
            ),
          if (_paths.length < _maxPhotos)
            SecondaryButton(
              key: const Key('markFixed.addPhoto'),
              label: l10n.issueActionsVerifyTakePhoto,
              icon: SaartheeIcons.camera,
              onPressed: _sending ? null : _addPhoto,
            ),
          const SizedBox(height: AppSpacing.s16),
          LabeledTextField(
            fieldKey: const Key('markFixed.note'),
            label: l10n.issueActionsMarkFixedNote,
            controller: _note,
            maxLines: 3,
          ),
          if (current != null && !current.actions.markFixed && !_sending) ...[
            const SizedBox(height: AppSpacing.s12),
            InlineFieldError(message: l10n.issueActionsForbidden),
          ],
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.s12),
            InlineFieldError(
              key: const Key('markFixed.error'),
              message: _error!,
            ),
          ],
          if (_stale)
            TertiaryButton(
              key: const Key('markFixed.reload'),
              label: l10n.issueActionsReload,
              onPressed: () {
                setState(() {
                  _stale = false;
                  _error = null;
                });
                refreshIssue(ref, widget.issueId);
              },
            ),
        ],
      ),
    );
  }
}
