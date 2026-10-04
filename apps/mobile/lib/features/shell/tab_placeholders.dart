import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import 'placeholders.dart';

/// Map tab body until TASK-07 (P-04).
class MapTabScreen extends StatelessWidget {
  const MapTabScreen({super.key});

  @override
  Widget build(BuildContext context) => PlaceholderScreen(
    title: AppLocalizations.of(context).navMap,
    placeholderId: PlaceholderId.p04Map,
  );
}

/// Report tab body until TASK-05 (P-05).
class ReportTabScreen extends StatelessWidget {
  const ReportTabScreen({super.key});

  @override
  Widget build(BuildContext context) => PlaceholderScreen(
    title: AppLocalizations.of(context).navReport,
    placeholderId: PlaceholderId.p05Report,
  );
}

/// Alerts tab body until TASK-08 (P-06).
class AlertsTabScreen extends StatelessWidget {
  const AlertsTabScreen({super.key});

  @override
  Widget build(BuildContext context) => PlaceholderScreen(
    title: AppLocalizations.of(context).navAlerts,
    placeholderId: PlaceholderId.p06Alerts,
  );
}
