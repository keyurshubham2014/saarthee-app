import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/tokens.dart';
import '../utils/formatters.dart';
import 'status_chip.dart';

/// Photo frame with a placeholder when the image is missing or fails.
class _PhotoFrame extends StatelessWidget {
  const _PhotoFrame({required this.image, required this.semanticLabel});

  final ImageProvider? image;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget placeholder() => Container(
      color: AppColors.indigoTint,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.hide_image_rounded, color: AppColors.inkMuted),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.photoMissing,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: ClipRRect(
        borderRadius: AppRadii.cardRadius,
        child: image == null
            ? placeholder()
            : Image(
                image: image!,
                fit: BoxFit.cover,
                semanticLabel: semanticLabel,
                errorBuilder: (_, _, _) => placeholder(),
              ),
      ),
    );
  }
}

/// Photo with capture time and GPS accuracy beneath it (02 §1.3).
class EvidencePhoto extends StatelessWidget {
  const EvidencePhoto({
    super.key,
    required this.image,
    this.capturedAt,
    this.accuracyMeters,
  });

  final ImageProvider? image;
  final DateTime? capturedAt;
  final double? accuracyMeters;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final time = capturedAt == null ? null : Formatters.dateTime(capturedAt!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PhotoFrame(
          image: image,
          semanticLabel: time == null
              ? l10n.photoMissing
              : l10n.photoSemanticLabel(time),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (time != null)
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 18,
                color: AppColors.inkMuted,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  l10n.photoCapturedAt(time),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        Row(
          children: [
            const Icon(
              Icons.location_on_rounded,
              size: 18,
              color: AppColors.inkMuted,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                accuracyMeters == null
                    ? l10n.photoNoLocation
                    : l10n.photoAccuracy(accuracyMeters!.round()),
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

enum BeforeAfterVariant { full, compact, citizenCheck }

/// Signature component (02 §2.5): report photo and latest verification photo
/// side by side at equal size, with the status stamp across the bottom.
/// Pass `after: null` with `beforeOnly: true` for unanswered complaints.
class BeforeAfterCard extends StatelessWidget {
  const BeforeAfterCard({
    super.key,
    required this.before,
    required this.after,
    required this.status,
    this.beforeDate,
    this.afterDate,
    this.variant = BeforeAfterVariant.full,
    this.beforeOnly = false,
  });

  final ImageProvider? before;
  final ImageProvider? after;
  final DateTime? beforeDate;
  final DateTime? afterDate;
  final ComplaintStatus status;
  final BeforeAfterVariant variant;
  final bool beforeOnly;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final style = StatusStyle.of(status);
    final statusWord = StatusStyle.label(l10n, status);
    final compact = variant == BeforeAfterVariant.compact;
    final gap = compact ? AppSpacing.xs : AppSpacing.sm;

    final beforeLabel = beforeDate == null
        ? null
        : l10n.photoReportedOn(Formatters.shortDate(beforeDate!));
    final afterLabel = afterDate == null
        ? null
        : l10n.photoNowOn(Formatters.shortDate(afterDate!));

    Widget column(ImageProvider? img, String? label) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PhotoFrame(image: img, semanticLabel: label ?? l10n.photoMissing),
          if (!compact && label != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );

    final stamp = Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: compact ? AppSpacing.xs : AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(AppRadii.card),
        ),
        border: Border(top: BorderSide(color: style.foreground, width: 2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(style.icon, color: style.foreground, size: compact ? 16 : 24),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              statusWord,
              style:
                  (compact
                          ? theme.textTheme.labelMedium
                          : theme.textTheme.titleMedium)
                      ?.copyWith(color: style.foreground),
            ),
          ),
        ],
      ),
    );

    return Semantics(
      container: true,
      label: [?beforeLabel, ?afterLabel, statusWord].join(', '),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: AppRadii.cardRadius,
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(gap),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  column(before, beforeLabel),
                  SizedBox(width: gap),
                  if (beforeOnly)
                    const Expanded(child: SizedBox.shrink())
                  else
                    column(after, afterLabel),
                ],
              ),
            ),
            stamp,
          ],
        ),
      ),
    );
  }
}
