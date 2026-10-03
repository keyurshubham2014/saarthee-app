import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/icons.dart';
import '../theme/tokens.dart';
import '../utils/formatters.dart';

/// 4:3 photo, radius 14, no border, required semantic label, optional
/// "Faces and number plates blurred" caption (DS §4 photos).
class PhotoThumb extends StatelessWidget {
  const PhotoThumb({
    super.key,
    required this.image,
    required this.semanticLabel,
    this.blurred = false,
    this.radius = AppRadii.control,
  });

  final ImageProvider? image;
  final String semanticLabel;
  final bool blurred;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    Widget placeholder() => Container(
      color: c.surfaceAlt,
      alignment: Alignment.center,
      child: Icon(SaartheeIcons.hideImage, color: c.textSecondary),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: semanticLabel,
          image: true,
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: image == null
                  ? placeholder()
                  : Image(
                      image: image!,
                      fit: BoxFit.cover,
                      excludeFromSemantics: true,
                      errorBuilder: (_, _, _) => placeholder(),
                    ),
            ),
          ),
        ),
        if (blurred) ...[
          const SizedBox(height: AppSpacing.s4),
          Text(
            l10n.photoBlurredCaption,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

/// Photo with capture time and GPS accuracy beneath it (capture preview).
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
    final c = SaartheeColors.of(context);
    final text = Theme.of(context).textTheme;
    final time = capturedAt == null ? null : Formatters.dateTime(capturedAt!);
    Widget meta(IconData icon, String value) => Row(
      children: [
        Icon(icon, size: AppSpacing.iconSmall, color: c.textSecondary),
        const SizedBox(width: AppSpacing.s4),
        Expanded(child: Text(value, style: text.bodySmall)),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PhotoThumb(
          image: image,
          semanticLabel: time == null
              ? l10n.photoMissing
              : l10n.photoSemanticLabel(time),
        ),
        const SizedBox(height: AppSpacing.s8),
        if (time != null) meta(SaartheeIcons.schedule, l10n.photoCapturedAt(time)),
        meta(
          SaartheeIcons.location,
          accuracyMeters == null
              ? l10n.photoNoLocation
              : l10n.photoAccuracy(accuracyMeters!.round()),
        ),
      ],
    );
  }
}
