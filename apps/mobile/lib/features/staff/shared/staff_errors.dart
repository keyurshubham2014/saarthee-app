import '../../../core/api/app_error.dart';
import '../../../core/api/error_messages.dart';
import '../../../core/l10n/app_localizations.dart';

/// Staff console error codes → ARB text. Anything else uses the shared
/// citizen map ([appErrorMessage]). Never returns the server's (English)
/// `message` or a raw code.
String staffErrorMessage(AppLocalizations l10n, Object error) {
  final e = AppError.from(error);
  return switch (e.code) {
    'ALERT_STATE_INVALID' => l10n.errorAlertStateInvalid,
    'ALERT_APPROVALS_MISSING' => l10n.errorAlertApprovalsMissing,
    'ALERT_ALREADY_APPROVED' => l10n.errorAlertAlreadyApproved,
    'ALERT_SECOND_APPROVER_ADMIN' => l10n.errorAlertSecondApproverAdmin,
    'ALERT_ALREADY_SUPERSEDED' => l10n.errorAlertSuperseded,
    'ALERT_INCOMPLETE' => l10n.errorAlertIncomplete,
    'MERGE_INVALID' => l10n.errorMergeInvalid,
    'SELF_SUSPEND' => l10n.errorSelfSuspend,
    'SELF_ROLE_CHANGE' => l10n.staffUsersSelf,
    'USER_STATE_INVALID' => l10n.errorUserStateInvalid,
    'ROLE_CHANGE_INVALID' => l10n.errorRoleChangeInvalid,
    'SETTING_UNKNOWN' => l10n.errorSettingUnknown,
    'INITIATIVE_NOT_STARTED' => l10n.errorInitiativeNotStarted,
    'NOT_VERIFIED' => l10n.errorNotVerified,
    'ALREADY_REPLIED' => l10n.errorAlreadyReplied,
    _ => appErrorMessage(l10n, e),
  };
}
