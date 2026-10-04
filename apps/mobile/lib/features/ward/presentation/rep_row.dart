import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/icons.dart';
import '../../../core/theme/tokens.dart';
import '../data/ward_models.dart';

/// Role word in the UI language.
String repRoleLabel(AppLocalizations l10n, String role) => switch (role) {
  'mla' => l10n.repRoleMla,
  'mp' => l10n.repRoleMp,
  _ => l10n.repRoleCorporator,
};

/// Initials avatar (DS §5): 40 dp `primaryContainer` circle, `primaryDark`
/// initials. No photos (ASSUMPTION TASK-09 §5.6).
class RepAvatar extends StatelessWidget {
  const RepAvatar({super.key, required this.initials, this.size = 40});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    return ExcludeSemantics(
      child: CircleAvatar(
        radius: size / 2,
        backgroundColor: c.primaryContainer,
        child: Text(
          initials,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(color: c.primaryDark),
        ),
      ),
    );
  }
}

/// Representative row (DS §5, TASK-09 §5.4): ≥ 72 dp, initials avatar, name
/// in the UI language with the other script below, role and party as plain
/// text (never a colour or logo), outlined "Message" button. Identical
/// layout for every representative (neutrality).
class WardRepRow extends StatelessWidget {
  const WardRepRow({
    super.key,
    required this.rep,
    required this.lang,
    required this.onOpen,
    required this.onMessage,
  });

  final RepSummary rep;
  final String lang;
  final VoidCallback onOpen;

  /// Null shows the button disabled (no official email) so every row keeps
  /// the same layout.
  final VoidCallback? onMessage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    final text = Theme.of(context).textTheme;
    final role = repRoleLabel(l10n, rep.role);
    final line = [role, ?rep.partyText].join(' · ');
    final messageLabel = rep.wardNumber != null
        ? l10n.repMessageSemantics(rep.name(lang), role, rep.wardNumber!)
        : l10n.repMessageSemanticsArea(rep.name(lang), role);
    return Material(
      color: NeemFixed.transparent,
      child: InkWell(
        onTap: onOpen,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.gutter,
              vertical: AppSpacing.s8,
            ),
            child: Row(
              children: [
                RepAvatar(initials: rep.initials),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(rep.name(lang), style: text.titleMedium),
                      Text(
                        rep.otherName(lang),
                        style: text.bodySmall?.copyWith(color: c.textSecondary),
                      ),
                      Text(line, style: text.bodySmall),
                    ],
                  ),
                ),
                ...[
                  const SizedBox(width: AppSpacing.s8),
                  Semantics(
                    container: true,
                    button: true,
                    enabled: onMessage != null,
                    label: messageLabel,
                    excludeSemantics: true,
                    child: OutlinedButton.icon(
                      key: Key('rep.message.${rep.id}'),
                      onPressed: onMessage,
                      icon: const Icon(
                        SaartheeIcons.message,
                        size: AppSpacing.iconSmall,
                      ),
                      label: Text(l10n.componentMessage),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(
                          AppSpacing.touchTarget,
                          AppSpacing.touchTarget,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Seat details being checked" row for an empty corporator seat.
class PendingSeatRow extends StatelessWidget {
  const PendingSeatRow({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 72),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: c.surfaceAlt,
              child: Icon(SaartheeIcons.hourglass, color: c.textSecondary),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Text(
                l10n.myWardSeatPending,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: c.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
