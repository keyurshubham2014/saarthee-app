import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../data/rep_claim_api.dart';

String repMethodLabel(AppLocalizations l10n, String? method) =>
    switch (method) {
      'official_gazette' => l10n.repClaimMethodGazette,
      'in_person' => l10n.repClaimMethodInPerson,
      'official_email' => l10n.repClaimMethodEmail,
      _ => l10n.repClaimMethodCertificate,
    };

/// TASK-11 verification row on `/representatives/:id` (REQ-F-053, AC-3/5):
/// verified → badge + "Checked by Saarthee on … · method · Valid until …";
/// expired → "Verification ended with the term" (no badge); unverified →
/// "Are you {name}? Claim this profile" link. Identical for every
/// representative (neutrality): no party colour.
class VerifiedRepBadge extends StatelessWidget {
  const VerifiedRepBadge({
    super.key,
    required this.verification,
    required this.repId,
    required this.name,
    this.canClaim = true,
  });

  final RepVerification verification;
  final String repId;
  final String name;

  /// False when the term has ended (claims are for the current term only).
  final bool canClaim;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    final text = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).languageCode;
    final v = verification;
    final pad = const EdgeInsets.symmetric(
      horizontal: AppSpacing.gutter,
      vertical: AppSpacing.s8,
    );
    if (v.isVerified) {
      final date = v.verifiedAt == null
          ? '—'
          : Formatters.date(v.verifiedAt!, locale);
      final until = v.validUntil == null
          ? '—'
          : Formatters.date(v.validUntil!, locale);
      return Padding(
        padding: pad,
        child: Semantics(
          key: const Key('repClaim.badge.verified'),
          container: true,
          label: l10n.repClaimVerifiedSemantics(date),
          child: ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s12,
                    vertical: AppSpacing.s4,
                  ),
                  decoration: ShapeDecoration(
                    color: c.primaryContainer,
                    shape: const StadiumBorder(),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        SaartheeIcons.statusVerified,
                        size: AppSpacing.iconSmall,
                        color: c.onPrimaryContainer,
                      ),
                      const SizedBox(width: AppSpacing.s4),
                      Text(
                        l10n.repClaimVerified,
                        style: text.labelLarge?.copyWith(
                          color: c.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s4),
                Text(
                  l10n.repClaimVerifiedHelper(
                    date,
                    repMethodLabel(l10n, v.method),
                    until,
                  ),
                  style: text.bodySmall?.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (v.isExpired) {
      return Padding(
        padding: pad,
        child: Text(
          l10n.repClaimExpired,
          key: const Key('repClaim.badge.expired'),
          style: text.bodyMedium?.copyWith(color: c.textSecondary),
        ),
      );
    }
    if (!canClaim) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton(
          key: const Key('repClaim.link'),
          onPressed: () => context.push('/representatives/$repId/claim'),
          child: Text(l10n.repClaimLink(name)),
        ),
      ),
    );
  }
}
