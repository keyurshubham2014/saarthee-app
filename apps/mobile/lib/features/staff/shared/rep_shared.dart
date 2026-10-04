import 'package:flutter/material.dart';

import '../../../core/api/app_error.dart';
import '../../../core/api/error_messages.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';

/// TASK-11 helpers shared by the staff console and the citizen claim flow
/// (kept here so the staff web build never reaches citizen-only code).

/// TASK-11 error codes → ARB text (falls back to the shared mapping).
String repErrorMessage(AppLocalizations l10n, Object error) {
  final e = AppError.from(error);
  return switch (e.code) {
    'CLAIM_ALREADY_PENDING' => l10n.repClaimErrorPending,
    'REPRESENTATIVE_ALREADY_VERIFIED' => l10n.repClaimErrorVerified,
    'REPRESENTATIVE_TERM_ENDED' => l10n.repClaimErrorTermEnded,
    'ROLE_CONFLICT' => l10n.repClaimErrorRoleConflict,
    'WARD_OUT_OF_SCOPE' => l10n.wardDashErrorOutOfScope,
    'ELECTION_MODE_FROZEN' => l10n.wardDashErrorFrozen,
    'CLAIM_NOT_PENDING' => l10n.repClaimConflict,
    _ => appErrorMessage(l10n, e),
  };
}

String repMethodLabel(AppLocalizations l10n, String? method) =>
    switch (method) {
      'official_gazette' => l10n.repClaimMethodGazette,
      'in_person' => l10n.repClaimMethodInPerson,
      'official_email' => l10n.repClaimMethodEmail,
      _ => l10n.repClaimMethodCertificate,
    };

/// Server status name → chip status (`merged` shown like rejected).
IssueStatus repIssueStatus(String s) => switch (s) {
  'sent' => IssueStatus.sent,
  'acknowledged' => IssueStatus.acknowledged,
  'in_progress' => IssueStatus.inProgress,
  'marked_fixed' => IssueStatus.markedFixed,
  'verified' => IssueStatus.verified,
  'reopened' => IssueStatus.reopened,
  'rejected' || 'merged' => IssueStatus.rejected,
  _ => IssueStatus.reported,
};

/// String value of a JSON field ('' when missing) — API data, not UI copy.
String jsonText(Map<String, dynamic> j, String key) =>
    (j[key] ?? '').toString();

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
