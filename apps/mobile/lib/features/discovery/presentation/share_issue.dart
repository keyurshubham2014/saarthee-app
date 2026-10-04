import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../data/discovery_models.dart';

/// Public web base for `/i/<id>` share and evidence links (TASK-13 domain).
const String kPublicWebBaseUrl = String.fromEnvironment(
  'PUBLIC_WEB_BASE_URL',
  defaultValue: 'https://saarthee.in',
);

/// Share sink; tests replace it.
typedef IssueSharer = Future<void> Function(String text);

final issueSharerProvider = Provider<IssueSharer>(
  (ref) =>
      (text) => SharePlus.instance.share(ShareParams(text: text)),
);

/// `<title> — <status>. See it on Saarthee: <base>/i/<id>` (REQ-F-032).
/// Never includes reporter information. Gujarati shares link to `?lang=gu`,
/// so the page and its WhatsApp preview are Gujarati too.
String issueShareText(AppLocalizations l10n, IssueDetail d) {
  final base = '${kPublicWebBaseUrl.replaceAll(RegExp(r'/$'), '')}/i/${d.id}';
  return l10n.discoveryShareText(
    d.title,
    issueStatusLabel(l10n, d.status),
    l10n.localeName.startsWith('gu') ? '$base?lang=gu' : base,
  );
}

Future<void> shareIssue(BuildContext context, WidgetRef ref, IssueDetail d) =>
    ref.read(issueSharerProvider)(
      issueShareText(AppLocalizations.of(context), d),
    );

/// Share card content (1080×1350 target; P1): wordmark, category, title,
/// ward, status, affected count, independence line — no reporter data.
/// Rendering it to PNG is deferred (see TASK-07 §13); the link is shared.
class IssueShareCard extends StatelessWidget {
  const IssueShareCard({super.key, required this.detail});

  final IssueDetail detail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final text = Theme.of(context).textTheme;
    final c = SaartheeColors.of(context);
    return Container(
      color: c.surface,
      padding: const EdgeInsets.all(AppSpacing.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Wordmark(),
          const SizedBox(height: AppSpacing.s16),
          CategoryBadge(slug: detail.categorySlug),
          const SizedBox(height: AppSpacing.s12),
          Text(detail.title, style: text.titleLarge),
          Text(detail.wardName(lang), style: text.bodyMedium),
          const SizedBox(height: AppSpacing.s12),
          StatusChip(status: detail.status),
          const SizedBox(height: AppSpacing.s12),
          Text(l10n.discoveryShareAffected(detail.meTooCount)),
          const SizedBox(height: AppSpacing.s16),
          Text(l10n.discoveryShareIndependence, style: text.bodySmall),
        ],
      ),
    );
  }
}
