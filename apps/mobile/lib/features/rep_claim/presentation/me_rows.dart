import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/settings/locale_controller.dart';
import '../../../core/theme/icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../data/rep_claim_api.dart';

/// Claim status chip: icon + word, DS §2 status tints (no new colours).
class ClaimStatusChip extends StatelessWidget {
  const ClaimStatusChip({super.key, required this.status, this.reason});

  final String status;
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (IssueStatus tone, String label) = switch (status) {
      'approved' => (IssueStatus.verified, l10n.repClaimStatusApproved),
      'rejected' => (
        IssueStatus.rejected,
        reason == null
            ? l10n.repClaimStatusRejected
            : l10n.repClaimStatusRejectedReason(reason!),
      ),
      'expired' => (IssueStatus.reported, l10n.repClaimStatusExpired),
      'withdrawn' => (IssueStatus.reported, l10n.repClaimStatusWithdrawn),
      'revoked' => (IssueStatus.rejected, l10n.repClaimStatusRevoked),
      _ => (IssueStatus.acknowledged, l10n.repClaimStatusPending),
    };
    return ToneChip(
      key: Key('claimStatus.$status'),
      tone: IssueStatusStyle.of(tone),
      label: label,
    );
  }
}

/// `/me` → "My representative claims" (hidden while there are none).
class MyRepClaimsRow extends ConsumerWidget {
  const MyRepClaimsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = SaartheeColors.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    final claims = ref.watch(myRepClaimsProvider).value ?? const [];
    if (claims.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.s16,
            AppSpacing.gutter,
            AppSpacing.s4,
          ),
          child: Text(
            l10n.repClaimMyRow,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        for (final cl in claims)
          ListRow(
            key: Key('me.repClaim.${cl.claimId}'),
            leading: Icon(SaartheeIcons.badge, color: c.textSecondary),
            title: cl.name(lang),
            trailing: ClaimStatusChip(
              status: cl.status,
              reason: cl.rejectReason,
            ),
            onTap: () => context.push('/representatives/${cl.repId}'),
          ),
      ],
    );
  }
}

/// `/me` → "My messages to representatives" (TASK-11 P2).
class MyMessagesRow extends StatelessWidget {
  const MyMessagesRow({super.key});

  @override
  Widget build(BuildContext context) {
    final c = SaartheeColors.of(context);
    return ListRow(
      key: const Key('me.repMessages'),
      leading: Icon(SaartheeIcons.message, color: c.textSecondary),
      title: AppLocalizations.of(context).repMsgMineRow,
      onTap: () => context.push('/me/messages'),
    );
  }
}
