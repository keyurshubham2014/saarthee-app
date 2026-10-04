import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../data/ward_models.dart';

/// Election-mode banner (DS §5 Banners, `warning` tint, `how_to_vote`):
/// "Election period until `date`. Some representative information is
/// paused." Announced as a live region. Hidden when election mode is off.
class ElectionBanner extends StatelessWidget {
  const ElectionBanner({super.key, required this.status});

  final ElectionStatus status;

  @override
  Widget build(BuildContext context) {
    if (!status.active) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final until = status.until;
    return Padding(
      key: const Key('ward.electionBanner'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.s8,
        AppSpacing.gutter,
        0,
      ),
      child: NoticeBanner(
        kind: NoticeKind.electionMode,
        rounded: true,
        message: until == null
            ? null
            : l10n.electionBannerText(Formatters.date(until, locale)),
      ),
    );
  }
}

/// Opens tel: and https: links. Tests override it.
final wardLauncherProvider = Provider<Future<bool> Function(Uri uri)>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);
