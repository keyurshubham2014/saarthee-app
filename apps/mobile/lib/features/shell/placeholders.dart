import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/icons.dart';
import '../../core/widgets/widgets.dart';

/// Placeholder register (TASK-03 §5.4). Each later task replaces its
/// entries; TASK-14 checks none remain in `lib/features`.
enum PlaceholderId {
  p01NearbyIssues('P-01', 'TASK-07'),
  p02AlertsStrip('P-02', 'TASK-08'),
  p03Drives('P-03', 'TASK-12'),
  p04Map('P-04', 'TASK-07'),
  p05Report('P-05', 'TASK-05'),
  p06Alerts('P-06', 'TASK-08'),
  p07Representatives('P-07', 'TASK-09'),
  p08WardServices('P-08', 'TASK-12'),
  p09Profile('P-09', 'TASK-04');

  const PlaceholderId(this.code, this.ownerTask);

  final String code;
  final String ownerTask;

  String message(AppLocalizations l10n) => switch (this) {
    p01NearbyIssues => l10n.placeholderNearbyIssues,
    p02AlertsStrip => l10n.placeholderAlertsStrip,
    p03Drives => l10n.placeholderDrives,
    p04Map => l10n.placeholderMap,
    p05Report => l10n.placeholderReport,
    p06Alerts => l10n.placeholderAlerts,
    p07Representatives => l10n.placeholderRepresentatives,
    p08WardServices => l10n.placeholderWardServices,
    p09Profile => l10n.placeholderProfile,
  };
}

/// A section that a later task fills (`EmptyState` with a construction icon;
/// owner task shown in debug builds only).
class PlaceholderSection extends StatelessWidget {
  const PlaceholderSection({super.key, required this.placeholderId});

  final PlaceholderId placeholderId;

  String get ownerTask => placeholderId.ownerTask;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      key: ValueKey('placeholder.${placeholderId.code}'),
      icon: SaartheeIcons.construction,
      message: placeholderId.message(AppLocalizations.of(context)),
      debugLabel: kDebugMode
          ? '${placeholderId.code} · ${placeholderId.ownerTask}'
          : null,
    );
  }
}

/// A whole tab body that a later task fills.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.placeholderId,
  });

  final String title;
  final PlaceholderId placeholderId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SaartheeAppBar(title: title, showBack: false),
      body: ListView(
        children: [
          const SizedBox(height: 48),
          PlaceholderSection(placeholderId: placeholderId),
        ],
      ),
    );
  }
}
