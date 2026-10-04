import '../../../core/l10n/app_localizations.dart';
import '../../../core/wards/ward.dart';
import '../../../core/widgets/widgets.dart';
import '../moderation/moderation_models.dart';

/// Citizen flag reasons (`moderation_flags.reason`), in sheet order.
const flagReasons = ['spam', 'abusive', 'private_info', 'not_civic', 'wrong_location', 'duplicate', 'other'];

String flagReasonLabel(AppLocalizations l10n, String r) => switch (r) {
  'spam' => l10n.flagReasonSpam,
  'abusive' => l10n.flagReasonAbusive,
  'private_info' => l10n.flagReasonPrivateInfo,
  'not_civic' => l10n.flagReasonNotCivic,
  'wrong_location' => l10n.flagReasonWrongLocation,
  'duplicate' => l10n.flagReasonDuplicate,
  _ => l10n.flagReasonOther,
};

/// Moderator reject reasons (`POST /staff/issues/{id}/reject`).
const rejectReasons = ['spam', 'duplicate', 'out_of_area', 'private_individual', 'not_civic', 'other'];

String rejectReasonLabel(AppLocalizations l10n, String r) => switch (r) {
  'spam' => l10n.staffRejectSpam,
  'duplicate' => l10n.staffRejectDuplicate,
  'out_of_area' => l10n.staffRejectOutOfArea,
  'private_individual' => l10n.staffRejectPrivate,
  'not_civic' => l10n.staffRejectNotCivic,
  _ => l10n.staffRejectOther,
};

String staffStatusLabel(AppLocalizations l10n, String status) {
  final s = issueStatusOf(status);
  return s == null ? l10n.staffStatusMerged : issueStatusLabel(l10n, s);
}

String staffEventLabel(AppLocalizations l10n, String type, String? toStatus) => switch (type) {
  'status_change' || 'rejected' when toStatus != null => staffStatusLabel(l10n, toStatus),
  'reviewed' => l10n.staffEventReviewed,
  'hidden' => l10n.staffEventHidden,
  'unhidden' => l10n.staffEventUnhidden,
  'recategorised' => l10n.staffEventRecategorised,
  'ward_changed' => l10n.staffEventWardChanged,
  'merged' => l10n.staffEventMerged,
  'comment' => l10n.staffEventComment,
  _ => l10n.staffEventOther,
};

/// "12 · Paldi" in the current language.
String staffWardText(Ward w, String lang) => '${w.number} · ${lang == 'gu' ? w.nameGu : w.nameEn}';
