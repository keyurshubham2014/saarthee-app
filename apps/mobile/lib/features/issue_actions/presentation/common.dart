import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/api/app_error.dart';
import '../../../core/api/error_messages.dart';
import '../../../core/config/app_config.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/photos.dart';

/// Issue photo from an API path (`/api/v1/media/photos/…`), 4:3, radius 14.
class IssuePhoto extends StatelessWidget {
  const IssuePhoto({super.key, required this.url, required this.label});

  final String? url;
  final String label;

  @override
  Widget build(BuildContext context) {
    final u = url;
    return PhotoThumb(
      image: u == null
          ? null
          : NetworkImage(Uri.parse(AppConfig.apiBaseUrl).resolve(u).toString()),
      semanticLabel: label,
    );
  }
}

/// Lifecycle error copy (TASK-06 §5.4); anything else uses the shared map.
String lifecycleErrorMessage(
  AppLocalizations l10n,
  AppError e, {
  int radius = 100,
}) => switch (e.code) {
  'STALE_STATUS' => l10n.issueActionsStale,
  'FORBIDDEN_ROLE' ||
  'OUT_OF_WARD' ||
  'FORBIDDEN' => l10n.issueActionsForbidden,
  'VERIFY_NOT_OPEN' => l10n.issueActionsVerifyClosed,
  'ALREADY_ANSWERED_TODAY' => l10n.issueActionsVerifyAlready,
  'LOCATION_TOO_INACCURATE' => l10n.issueActionsVerifyInaccurate,
  _ => appErrorMessage(l10n, e),
};

/// Great-circle metres (same formula as the API's haversine fallback).
double haversineMetres(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371008.8;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.min(1, math.sqrt(a)));
}

/// "Step n of 2" header line used by the verify flow (TalkBack reads it).
class VerifyStepLabel extends StatelessWidget {
  const VerifyStepLabel({super.key, required this.step});
  final int step;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      header: true,
      child: Text(
        l10n.commonStepOf(step, 2),
        style: Theme.of(context).textTheme.labelLarge
            ?.copyWith(color: SaartheeColors.of(context).textSecondary),
      ),
    );
  }
}
