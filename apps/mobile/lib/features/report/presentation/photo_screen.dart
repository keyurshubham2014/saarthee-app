import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/error_messages.dart';
import '../../../core/capture/capture_panel.dart';
import '../../../core/connectivity/connectivity_provider.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../application/report_draft_controller.dart';
import 'report_step_mixin.dart';

/// Step 4: Photo of the problem (02 §4.7).
class PhotoScreen extends ConsumerStatefulWidget {
  const PhotoScreen({super.key});

  @override
  ConsumerState<PhotoScreen> createState() => _PhotoScreenState();
}

class _PhotoScreenState extends ConsumerState<PhotoScreen>
    with ReportStepMixin {
  @override
  String get stepRoute => ReportRoutes.photo;

  bool _retaking = false;
  bool _attempted = false;

  @override
  void initState() {
    super.initState();
    // Resume an upload that never finished (e.g. app was closed).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final d = ref.read(reportDraftProvider);
      if (d?.hasPhoto == true && d?.photoId == null) {
        ref.read(reportUploadProvider.notifier).upload();
      }
    });
  }

  void _continue() {
    final d = ref.read(reportDraftProvider);
    setState(() => _attempted = true);
    if (d?.photoId != null) goNext(ReportRoutes.phone);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final draft = ref.watch(reportDraftProvider);
    final upload = ref.watch(reportUploadProvider);
    final offline = ref.watch(isOfflineProvider);

    // Retry automatically when the connection comes back.
    ref.listen(isOnlineProvider, (prev, next) {
      if (next.value == true &&
          ref.read(reportUploadProvider).status == UploadStatus.failed) {
        ref.read(reportUploadProvider.notifier).upload();
      }
    });

    final hasPhoto = draft?.hasPhoto == true && !_retaking;
    final uploadFailed = upload.status == UploadStatus.failed;

    return StepScaffold(
      step: 4,
      total: kReportSteps,
      title: l10n.reportPhotoTitle,
      onBack: () => goBack(ReportRoutes.number),
      showOfflineBanner: offline || (upload.error?.isOffline ?? false),
      onRetryOffline: uploadFailed
          ? () => ref.read(reportUploadProvider.notifier).upload()
          : null,
      actions: [
        PrimaryButton(
          key: const Key('report.photo.continue'),
          label: l10n.commonContinue,
          onPressed: hasPhoto && draft?.photoId != null ? _continue : null,
        ),
      ],
      children: [
        Text(l10n.reportPhotoRationale, style: theme.textTheme.bodyLarge),
        const SizedBox(height: AppSpacing.xl),
        if (!hasPhoto)
          CapturePanel(
            keyPrefix: 'report.photo',
            onUse: (photo, fix) async {
              ref.read(reportUploadProvider.notifier).reset();
              await ref
                  .read(reportDraftProvider.notifier)
                  .setPhoto(
                    sourcePath: photo.path,
                    latitude: fix.latitude,
                    longitude: fix.longitude,
                    accuracy: fix.accuracy,
                    capturedAt: photo.capturedAt,
                  );
              if (mounted) setState(() => _retaking = false);
              await ref.read(reportUploadProvider.notifier).upload();
            },
          )
        else ...[
          EvidencePhoto(
            image: FileImage(File(draft!.photoPath!)),
            capturedAt: draft.deviceCapturedAt,
            accuracyMeters: draft.gpsAccuracyM,
          ),
          const SizedBox(height: AppSpacing.md),
          if (upload.status == UploadStatus.uploading) ...[
            Semantics(
              label: l10n.reportPhotoUploading,
              value: '${(upload.progress * 100).round()}%',
              child: LinearProgressIndicator(value: upload.progress),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.reportPhotoUploading, style: theme.textTheme.bodySmall),
          ],
          if (draft.photoId != null)
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
          if (uploadFailed) ...[
            InlineFieldError(
              message: upload.error!.isOffline
                  ? l10n.reportPhotoUploadFailed
                  : '${l10n.reportPhotoUploadFailed} ${appErrorMessage(l10n, upload.error!)}',
            ),
            const SizedBox(height: AppSpacing.sm),
            SecondaryButton(
              key: const Key('report.photo.retryUpload'),
              label: l10n.reportPhotoRetryUpload,
              icon: Icons.refresh_rounded,
              onPressed: () => ref.read(reportUploadProvider.notifier).upload(),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          SecondaryButton(
            key: const Key('report.photo.retakeSaved'),
            label: l10n.reportPhotoRetake,
            icon: Icons.photo_camera_rounded,
            onPressed: upload.status == UploadStatus.uploading
                ? null
                : () => setState(() => _retaking = true),
          ),
          if (_attempted && draft.photoId == null)
            InlineFieldError(message: l10n.reportPhotoUploadRequired),
        ],
      ],
    );
  }
}
