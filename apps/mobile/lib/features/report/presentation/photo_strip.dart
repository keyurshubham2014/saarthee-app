import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/icons.dart';
import '../../../core/theme/tokens.dart';
import '../application/report_draft_controller.dart';

/// Up to three 4:3 thumbnails (radius 14) with remove, upload state, blur
/// caption and "Blur more"; the next free slot is an empty placeholder whose
/// key is the photo fly-in target.
class PhotoStrip extends StatelessWidget {
  const PhotoStrip({
    super.key,
    required this.photos,
    required this.slotKeys,
    required this.onRemove,
    required this.onRetry,
    required this.onBlurMore,
    this.maxPhotos = 3,
  });

  final List<DraftPhoto> photos;
  final List<GlobalKey> slotKeys;
  final ValueChanged<DraftPhoto> onRemove;
  final ValueChanged<DraftPhoto> onRetry;
  final ValueChanged<DraftPhoto> onBlurMore;
  final int maxPhotos;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < maxPhotos; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: KeyedSubtree(
              key: slotKeys[i],
              child: i < photos.length
                  ? _Thumb(
                      photo: photos[i],
                      index: i,
                      onRemove: onRemove,
                      onRetry: onRetry,
                      onBlurMore: onBlurMore,
                    )
                  : const _EmptySlot(),
            ),
          ),
        ],
      ],
    );
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot();

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: AppRadii.controlRadius,
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.photo,
    required this.index,
    required this.onRemove,
    required this.onRetry,
    required this.onBlurMore,
  });

  final DraftPhoto photo;
  final int index;
  final ValueChanged<DraftPhoto> onRemove;
  final ValueChanged<DraftPhoto> onRetry;
  final ValueChanged<DraftPhoto> onBlurMore;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    final text = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final time = DateFormat('d MMM, h:mm a', locale).format(photo.capturedAt);
    final state = photo.uploadState;
    final busy =
        state == UploadState.blurring || state == UploadState.uploading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 4 / 3,
          child: ClipRRect(
            borderRadius: AppRadii.controlRadius,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Semantics(
                  image: true,
                  label: l10n.reportFlowPhotoLabel(index + 1, time),
                  child: Image.file(
                    File(photo.localPath),
                    key: ValueKey('report.thumb.$index'),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => ColoredBox(color: c.surfaceAlt),
                  ),
                ),
                if (busy)
                  ColoredBox(
                    color: c.surface.withValues(alpha: 0.6),
                    child: const Center(
                      child: SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    tooltip: l10n.reportFlowRemovePhoto(index + 1),
                    onPressed: () => onRemove(photo),
                    style: IconButton.styleFrom(backgroundColor: c.surface),
                    icon: const Icon(SaartheeIcons.close, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s4),
        if (state == UploadState.blurring)
          Text(l10n.reportFlowBlurring, style: text.bodySmall)
        else if (state == UploadState.uploading)
          LinearProgressIndicator(
            value: photo.progress == 0 ? null : photo.progress,
          )
        else if (state == UploadState.failed)
          TextButton(
            key: ValueKey('report.retry.$index'),
            onPressed: () => onRetry(photo),
            child: Text(l10n.reportFlowRetryUpload),
          )
        else ...[
          if (photo.blurApplied)
            Text(l10n.reportFlowBlurred, style: text.bodySmall),
          TextButton(
            onPressed: () => onBlurMore(photo),
            child: Text(l10n.reportFlowBlurMore),
          ),
        ],
      ],
    );
  }
}
