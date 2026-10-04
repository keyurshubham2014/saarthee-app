import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/app_error.dart';
import '../../../core/capture/evidence_capture.dart';
import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../application/issue_providers.dart';
import '../application/photo_prep.dart';
import '../data/issue_actions_api.dart';
import '../data/issue_models.dart';
import 'common.dart';
import 'motion/send_progress_button.dart';

/// Outcome toast copy (DS §8 v2.2 replaces the `/verify/done` screen).
String verifyOutcomeMessage(AppLocalizations l10n, String status) =>
    switch (status) {
      'verified' => l10n.issueActionsVerifyToastVerified,
      'reopened' => l10n.issueActionsVerifyToastReopened,
      _ => l10n.issueActionsVerifyToastRecorded,
    };

/// `/issues/:id/verify/photo?answer=fixed|not_fixed` — step 2 of 2: photo
/// at the spot, live distance, optional note, pinned Send with in-button
/// progress; success returns to the issue with a drawn-check toast.
class VerifyPhotoScreen extends ConsumerStatefulWidget {
  const VerifyPhotoScreen({
    super.key,
    required this.issueId,
    required this.answer,
  });

  final String issueId;
  final String answer;

  @override
  ConsumerState<VerifyPhotoScreen> createState() => _VerifyPhotoScreenState();
}

class _VerifyPhotoScreenState extends ConsumerState<VerifyPhotoScreen> {
  final _note = TextEditingController();
  final String _submissionId = newActionId();
  CapturedPhoto? _photo;
  Fix? _fix;
  String? _photoId;
  bool _locating = false;
  bool _sending = false;
  bool _waitingForNetwork = false;
  bool _uploadFailed = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _take() async {
    final capture = ref.read(evidenceCaptureProvider);
    final photo = await capture.takePhoto();
    if (photo == null || !mounted) return;
    setState(() {
      _photo = photo;
      _photoId = null;
      _fix = null;
      _locating = true;
      _error = null;
    });
    final fix = await capture.currentFix();
    if (!mounted) return;
    setState(() {
      _fix = fix;
      _locating = false;
    });
  }

  int? _distance(IssueLifecycle i) => _fix == null
      ? null
      : haversineMetres(
          _fix!.latitude,
          _fix!.longitude,
          i.latitude,
          i.longitude,
        ).round();

  Future<void> _send(IssueLifecycle issue) async {
    final l10n = AppLocalizations.of(context);
    final api = ref.read(issueActionsApiProvider);
    setState(() {
      _sending = true;
      _error = null;
      _uploadFailed = false;
      _waitingForNetwork = false;
    });
    try {
      _photoId ??= await ref
          .read(issuePhotoUploaderProvider)
          .upload(widget.issueId, _photo!.path, 'verification');
    } on AppError catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _waitingForNetwork = e.isOffline;
        _uploadFailed = !e.isOffline;
        _error = e.isOffline
            ? l10n.issueActionsVerifyOffline
            : lifecycleErrorMessage(l10n, e);
      });
      return;
    }
    try {
      final result = await api.verify(widget.issueId, {
        'clientSubmissionId': _submissionId,
        'answer': widget.answer,
        'photoId': _photoId,
        'latitude': _fix!.latitude,
        'longitude': _fix!.longitude,
        'gpsAccuracyM': _fix!.accuracy,
        'deviceCapturedAt': _photo!.capturedAt.toUtc().toIso8601String(),
        if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
      });
      if (!mounted) return;
      refreshIssue(ref, widget.issueId);
      final router = GoRouter.of(context);
      showSaartheeToast(context, verifyOutcomeMessage(l10n, result.status));
      router.go('/issues/${widget.issueId}');
    } on AppError catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _waitingForNetwork = e.isOffline;
        _error = e.isOffline
            ? l10n.issueActionsVerifyOffline
            : e.code == 'TOO_FAR_FROM_ISSUE'
            ? l10n.issueActionsVerifyTooFar(
                issue.verifyRadiusM,
                _distance(issue) ?? 0,
              )
            : lifecycleErrorMessage(l10n, e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final issue = ref.watch(issueLifecycleProvider(widget.issueId)).value;
    ref.listen(isOnlineProvider, (_, next) {
      if (next.value == true &&
          _waitingForNetwork &&
          !_sending &&
          issue != null) {
        _send(issue);
      }
    });
    if (issue == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.issueActionsVerifyPhotoTitle)),
        body: const SkeletonList(count: 3),
      );
    }
    final distance = _distance(issue);
    final inaccurate =
        _fix != null && _fix!.accuracy > issue.verifyMaxAccuracyM;
    final tooFar =
        !inaccurate && distance != null && distance > issue.verifyRadiusM;
    final ready = _photo != null && _fix != null && !inaccurate && !tooFar;
    final String? status = _locating
        ? l10n.issueActionsVerifyLocating
        : inaccurate
        ? l10n.issueActionsVerifyInaccurate
        : tooFar
        ? l10n.issueActionsVerifyTooFar(issue.verifyRadiusM, distance)
        : distance != null
        ? l10n.issueActionsVerifyDistance(distance)
        : null;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.issueActionsVerifyPhotoTitle)),
      body: PinnedBottomLayout(
        top: const Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.s8,
            AppSpacing.gutter,
            0,
          ),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: VerifyStepLabel(step: 2),
          ),
        ),
        bottom: [
          SizedBox(
            width: double.infinity,
            child: SendProgressButton(
              label: _uploadFailed
                  ? l10n.issueActionsVerifyRetryUpload
                  : l10n.issueActionsVerifySend,
              sending: _sending,
              onPressed: ready ? () => _send(issue) : null,
            ),
          ),
        ],
        children: [
          Text(l10n.issueActionsVerifyPhotoTitle, style: text.headlineSmall),
          const SizedBox(height: AppSpacing.s16),
          if (_photo != null)
            PhotoThumb(
              image: FileImage(File(_photo!.path)),
              semanticLabel: l10n.issueActionsVerifyAfter,
            ),
          const SizedBox(height: AppSpacing.s8),
          SecondaryButton(
            key: const Key('verify.take'),
            label: _photo == null
                ? l10n.issueActionsVerifyTakePhoto
                : l10n.issueActionsVerifyRetake,
            onPressed: _sending ? null : _take,
          ),
          if (status != null) ...[
            const SizedBox(height: AppSpacing.s12),
            Semantics(
              liveRegion: true,
              child: Text(
                status,
                key: const Key('verify.distance'),
                style: text.bodyLarge,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.s16),
          LabeledTextField(
            fieldKey: const Key('verify.note'),
            label: l10n.issueActionsVerifyNoteLabel,
            controller: _note,
            maxLines: 3,
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.s12),
            InlineFieldError(key: const Key('verify.error'), message: _error!),
          ],
        ],
      ),
    );
  }
}
