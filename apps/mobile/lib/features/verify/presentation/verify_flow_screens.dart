import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/app_error.dart';
import '../../../core/api/error_messages.dart';
import '../../../core/capture/capture_panel.dart';
import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../../report/presentation/done_screen.dart';
import '../application/verify_session_controller.dart';

/// Guards verify steps: without a loaded session (e.g. app restarted, the
/// token is memory-only) the citizen is sent back to the entry screen.
bool _sessionMissing(VerifySession s) =>
    s.load != VerifyLoad.ready || s.summary == null;

Widget _missing(BuildContext context) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (context.mounted) context.go(VerifyRoutes.entry);
  });
  return const Scaffold();
}

bool _fromCheck(BuildContext context) =>
    GoRouterState.of(context).uri.queryParameters['from'] == 'check';

/// `/verify/answer` (02 §4.13).
class VerifyAnswerScreen extends ConsumerStatefulWidget {
  const VerifyAnswerScreen({super.key});

  @override
  ConsumerState<VerifyAnswerScreen> createState() => _VerifyAnswerScreenState();
}

class _VerifyAnswerScreenState extends ConsumerState<VerifyAnswerScreen> {
  bool _attempted = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = ref.watch(verifySessionProvider);
    if (_sessionMissing(s)) return _missing(context);
    final c = ref.read(verifySessionProvider.notifier);
    final fromCheck = _fromCheck(context);

    void next() {
      setState(() => _attempted = true);
      if (s.answer == null) return;
      if (fromCheck && s.photoId != null) {
        context.go(
          s.answer == VerifyAnswer.notFixed
              ? '${VerifyRoutes.note}?from=check'
              : VerifyRoutes.check,
        );
      } else {
        context.go(VerifyRoutes.photo);
      }
    }

    return StepScaffold(
      step: 1,
      total: s.totalSteps,
      title: l10n.verifyAnswerTitle,
      onBack: () =>
          context.go(fromCheck ? VerifyRoutes.check : VerifyRoutes.entry),
      actions: [
        PrimaryButton(
          key: const Key('verify.answer.continue'),
          label: l10n.commonContinue,
          onPressed: next,
        ),
      ],
      children: [
        ChoiceCard(
          key: const Key('verify.answer.fixed'),
          label: l10n.verifyAnswerFixed,
          icon: Icons.check_rounded,
          tone: ChoiceTone.fixed,
          selected: s.answer == VerifyAnswer.fixed,
          onTap: () => c.setAnswer(VerifyAnswer.fixed),
        ),
        const SizedBox(height: AppSpacing.md),
        ChoiceCard(
          key: const Key('verify.answer.notFixed'),
          label: l10n.verifyAnswerNotFixed,
          icon: Icons.close_rounded,
          tone: ChoiceTone.notFixed,
          selected: s.answer == VerifyAnswer.notFixed,
          onTap: () => c.setAnswer(VerifyAnswer.notFixed),
        ),
        if (_attempted && s.answer == null)
          InlineFieldError(message: l10n.verifyAnswerRequired),
      ],
    );
  }
}

/// `/verify/photo` (02 §4.14).
class VerifyPhotoScreen extends ConsumerStatefulWidget {
  const VerifyPhotoScreen({super.key});

  @override
  ConsumerState<VerifyPhotoScreen> createState() => _VerifyPhotoScreenState();
}

class _VerifyPhotoScreenState extends ConsumerState<VerifyPhotoScreen> {
  bool _retaking = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final s = ref.watch(verifySessionProvider);
    if (_sessionMissing(s)) return _missing(context);
    final c = ref.read(verifySessionProvider.notifier);
    final offline = ref.watch(isOfflineProvider);
    final fromCheck = _fromCheck(context);

    ref.listen(isOnlineProvider, (prev, next) {
      if (next.value == true &&
          ref.read(verifySessionProvider).upload == VerifyUpload.failed) {
        c.uploadPhoto();
      }
    });

    final hasPhoto = s.photoPath != null && !_retaking;
    final failed = s.upload == VerifyUpload.failed;

    void next() {
      if (s.photoId == null) return;
      if (s.answer == VerifyAnswer.notFixed && !fromCheck) {
        context.go(VerifyRoutes.note);
      } else {
        context.go(VerifyRoutes.check);
      }
    }

    return StepScaffold(
      step: 2,
      total: s.totalSteps,
      title: l10n.verifyPhotoTitle,
      onBack: () =>
          context.go(fromCheck ? VerifyRoutes.check : VerifyRoutes.answer),
      showOfflineBanner: offline || (s.uploadError?.isOffline ?? false),
      onRetryOffline: failed ? c.uploadPhoto : null,
      actions: [
        PrimaryButton(
          key: const Key('verify.photo.continue'),
          label: l10n.commonContinue,
          onPressed: hasPhoto && s.photoId != null ? next : null,
        ),
      ],
      children: [
        if (s.reportPhoto != null) ...[
          Text(l10n.verifyPhotoReference, style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 120,
              child: ClipRRect(
                borderRadius: AppRadii.cardRadius,
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: Image.memory(
                    s.reportPhoto!,
                    fit: BoxFit.cover,
                    semanticLabel: l10n.verifyPhotoReference,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
        if (!hasPhoto)
          CapturePanel(
            keyPrefix: 'verify.photo',
            onUse: (photo, fix) async {
              if (mounted) setState(() => _retaking = false);
              await c.setPhoto(photo, fix);
            },
          )
        else ...[
          EvidencePhoto(
            image: FileImage(File(s.photoPath!)),
            capturedAt: s.capturedAt,
            accuracyMeters: s.fix?.accuracy,
          ),
          const SizedBox(height: AppSpacing.md),
          if (s.upload == VerifyUpload.uploading) ...[
            Semantics(
              label: l10n.reportPhotoUploading,
              value: '${(s.uploadProgress * 100).round()}%',
              child: LinearProgressIndicator(value: s.uploadProgress),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.reportPhotoUploading, style: theme.textTheme.bodySmall),
          ],
          if (s.photoId != null)
            Row(
              children: [
                const Icon(Icons.cloud_done_rounded, color: AppColors.fixed),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  l10n.reportPhotoUploaded,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          if (failed) ...[
            InlineFieldError(
              message: s.uploadError!.isOffline
                  ? l10n.reportPhotoUploadFailed
                  : '${l10n.reportPhotoUploadFailed} ${appErrorMessage(l10n, s.uploadError!)}',
            ),
            const SizedBox(height: AppSpacing.sm),
            SecondaryButton(
              key: const Key('verify.photo.retryUpload'),
              label: l10n.reportPhotoRetryUpload,
              icon: Icons.refresh_rounded,
              onPressed: c.uploadPhoto,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          SecondaryButton(
            key: const Key('verify.photo.retakeSaved'),
            label: l10n.reportPhotoRetake,
            icon: Icons.photo_camera_rounded,
            onPressed: s.upload == VerifyUpload.uploading
                ? null
                : () => setState(() => _retaking = true),
          ),
        ],
      ],
    );
  }
}

/// `/verify/note` (02 §4.15), only after "Not fixed".
class VerifyNoteScreen extends ConsumerStatefulWidget {
  const VerifyNoteScreen({super.key});

  @override
  ConsumerState<VerifyNoteScreen> createState() => _VerifyNoteScreenState();
}

class _VerifyNoteScreenState extends ConsumerState<VerifyNoteScreen> {
  late final TextEditingController _controller = TextEditingController(
    text: ref.read(verifySessionProvider).note,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final s = ref.watch(verifySessionProvider);
    if (_sessionMissing(s)) return _missing(context);
    final c = ref.read(verifySessionProvider.notifier);
    final fromCheck = _fromCheck(context);

    return StepScaffold(
      step: 3,
      total: s.totalSteps,
      title: l10n.verifyNoteTitle,
      onBack: () =>
          context.go(fromCheck ? VerifyRoutes.check : VerifyRoutes.photo),
      actions: [
        PrimaryButton(
          key: const Key('verify.note.continue'),
          label: l10n.commonContinue,
          onPressed: () {
            c.setNote(_controller.text);
            context.go(VerifyRoutes.check);
          },
        ),
        SecondaryButton(
          key: const Key('verify.note.skip'),
          label: l10n.commonSkip,
          onPressed: () {
            c.setNote('');
            context.go(VerifyRoutes.check);
          },
        ),
      ],
      children: [
        Text(l10n.verifyNoteBody, style: theme.textTheme.bodyLarge),
        const SizedBox(height: AppSpacing.xl),
        TextField(
          key: const Key('verify.note.field'),
          controller: _controller,
          minLines: 4,
          maxLines: 8,
          maxLength: 1000,
          textCapitalization: TextCapitalization.sentences,
          style: theme.textTheme.bodyLarge,
          decoration: InputDecoration(
            labelText: l10n.verifyNoteLabel,
            alignLabelWithHint: true,
          ),
          onChanged: c.setNote,
        ),
      ],
    );
  }
}

/// `/verify/check` (02 §4.16).
class VerifyCheckScreen extends ConsumerWidget {
  const VerifyCheckScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final s = ref.watch(verifySessionProvider);
    if (_sessionMissing(s)) return _missing(context);
    final c = ref.read(verifySessionProvider.notifier);
    final offline = ref.watch(isOfflineProvider);
    final error = s.submitError;
    final notFixed = s.answer == VerifyAnswer.notFixed;
    final complete = s.answer != null && s.photoId != null;

    Future<void> send() async {
      final ok = await c.submit();
      if (ok && context.mounted) context.go(VerifyRoutes.done);
    }

    List<ErrorSummaryItem> summary(AppError e) {
      void toPhoto() => context.go('${VerifyRoutes.photo}?from=check');
      if (e.code == 'PHOTO_UNUSABLE') {
        return [ErrorSummaryItem(l10n.errorPhotoUnusable, onTap: toPhoto)];
      }
      if (e.code == 'VALIDATION_FAILED' && e.details.isNotEmpty) {
        final seen = <String>{};
        final items = <ErrorSummaryItem>[];
        for (final d in e.details) {
          final ErrorSummaryItem item;
          if (d.field == 'note') {
            item = ErrorSummaryItem(
              l10n.verifyNoteTooLong,
              onTap: () => context.go('${VerifyRoutes.note}?from=check'),
            );
          } else if (d.field == 'deviceCapturedAt') {
            item = ErrorSummaryItem(l10n.reportErrorClock, onTap: toPhoto);
          } else if (d.field == 'latitude' || d.field == 'longitude') {
            item = ErrorSummaryItem(l10n.reportErrorLocation, onTap: toPhoto);
          } else if (d.field == 'result') {
            item = ErrorSummaryItem(
              l10n.verifyAnswerRequired,
              onTap: () => context.go('${VerifyRoutes.answer}?from=check'),
            );
          } else {
            item = ErrorSummaryItem(l10n.errorPhotoUnusable, onTap: toPhoto);
          }
          if (seen.add(item.message)) items.add(item);
        }
        return items;
      }
      return [ErrorSummaryItem(appErrorMessage(l10n, e))];
    }

    Widget changeRow(String label, String value, String route) => Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(value, style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
          Semantics(
            label: l10n.reportCheckChangeLabel(label),
            excludeSemantics: true,
            button: true,
            child: TextButton(
              key: Key('verify.check.change.$route'),
              onPressed: s.sending
                  ? null
                  : () => context.go('$route?from=check'),
              child: Text(l10n.commonChange),
            ),
          ),
        ],
      ),
    );

    return StepScaffold(
      step: s.totalSteps,
      total: s.totalSteps,
      title: l10n.verifyCheckTitle,
      onBack: () =>
          context.go(notFixed ? VerifyRoutes.note : VerifyRoutes.photo),
      showOfflineBanner: offline || (error?.isOffline ?? false),
      onRetryOffline: error?.isOffline == true ? send : null,
      actions: [
        PrimaryButton(
          key: const Key('verify.check.send'),
          label: l10n.commonSend,
          loading: s.sending,
          onPressed: complete ? send : null,
        ),
      ],
      children: [
        if (error != null && !error.isOffline) ...[
          AppErrorSummary(items: summary(error)),
          const SizedBox(height: AppSpacing.lg),
        ],
        BeforeAfterCard(
          variant: BeforeAfterVariant.citizenCheck,
          before: s.reportPhoto == null ? null : MemoryImage(s.reportPhoto!),
          after: s.photoPath == null ? null : FileImage(File(s.photoPath!)),
          beforeDate: s.summary!.reportedAt,
          afterDate: s.capturedAt,
          status: notFixed ? ComplaintStatus.notFixed : ComplaintStatus.fixed,
        ),
        const SizedBox(height: AppSpacing.md),
        changeRow(
          l10n.verifyCheckAnswer,
          notFixed ? l10n.verifyAnswerNotFixed : l10n.verifyAnswerFixed,
          VerifyRoutes.answer,
        ),
        const Divider(),
        changeRow(
          l10n.verifyCheckPhoto,
          l10n.reportPhotoUploaded,
          VerifyRoutes.photo,
        ),
        if (notFixed) ...[
          const Divider(),
          changeRow(
            l10n.verifyCheckNote,
            s.note.trim().isEmpty ? l10n.verifyCheckNoNote : s.note.trim(),
            VerifyRoutes.note,
          ),
        ],
      ],
    );
  }
}

/// `/verify/done` (02 §4.16). "Done" ends the in-memory session.
class VerifyDoneScreen extends ConsumerWidget {
  const VerifyDoneScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return ConfirmationScreen(
      buttonKey: const Key('verify.done'),
      title: l10n.verifyDoneTitle,
      body: l10n.verifyDoneBody,
      onDone: () => ref.read(verifySessionProvider.notifier).finish(),
    );
  }
}
