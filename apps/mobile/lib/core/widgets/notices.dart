import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/icons.dart';
import '../theme/tokens.dart';

enum NoticeKind { offline, electionMode, independence, info }

/// Banners (DS §5): offline (slate), election mode, independence notice,
/// info. Icon + text, announced as a live region.
class NoticeBanner extends StatelessWidget {
  const NoticeBanner({
    super.key,
    required this.kind,
    this.message,
    this.onRetry,
    this.rounded = false,
  });

  final NoticeKind kind;

  /// Overrides the default copy for the kind.
  final String? message;
  final VoidCallback? onRetry;

  /// Rounded card (in content) instead of a full-width strip.
  final bool rounded;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    final (IconData icon, Color fg, Color bg, String text) = switch (kind) {
      NoticeKind.offline => (
        SaartheeIcons.offline,
        c.textPrimary,
        c.offlineTint,
        l10n.commonOfflineBanner,
      ),
      NoticeKind.electionMode => (
        SaartheeIcons.election,
        c.textPrimary,
        c.warningTint,
        l10n.componentElectionBanner,
      ),
      NoticeKind.independence => (
        SaartheeIcons.info,
        c.textPrimary,
        c.infoTint,
        l10n.commonIndependenceNotice,
      ),
      NoticeKind.info => (SaartheeIcons.info, c.textPrimary, c.infoTint, ''),
    };
    final iconColor = switch (kind) {
      NoticeKind.offline => c.offline,
      NoticeKind.electionMode => c.warning,
      _ => c.info,
    };
    final retry = onRetry == null
        ? null
        : TextButton(onPressed: onRetry, child: Text(l10n.commonRetry));
    // Large text (≥ 1.5×, DS §7): "Try again" moves under the message so
    // the row never overflows.
    final stacked = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        key: ValueKey('notice.${kind.name}'),
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: rounded ? AppSpacing.s16 : AppSpacing.gutter,
          vertical: AppSpacing.s12,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: rounded ? AppRadii.cardRadius : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: iconColor, size: AppSpacing.iconSize),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message ?? text,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: fg),
                  ),
                  if (stacked && retry != null) retry,
                ],
              ),
            ),
            if (!stacked && retry != null) retry,
          ],
        ),
      ),
    );
  }
}

/// The independence line, used in onboarding, About and hand-offs.
class IndependenceNotice extends StatelessWidget {
  const IndependenceNotice({super.key});

  @override
  Widget build(BuildContext context) =>
      const NoticeBanner(kind: NoticeKind.independence, rounded: true);
}
