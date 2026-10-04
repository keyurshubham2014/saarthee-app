import '../../../core/api/app_error.dart';
import '../../../core/api/error_messages.dart';
import '../../../core/l10n/app_localizations.dart';
import '../application/report_draft_controller.dart';

/// Where an error summary link should take the citizen (TASK-05 §5.4).
class ReportErrorView {
  const ReportErrorView(this.message, {this.step});

  final String message;
  final ReportStep? step;
}

/// Maps a submit / me-too error to copy and the step that fixes it.
ReportErrorView reportError(
  AppLocalizations l10n,
  AppError e, {
  int quotaPerDay = 10,
}) {
  switch (e.code) {
    case 'PHOTO_UNUSABLE':
      return ReportErrorView(
        l10n.reportFlowPhotoExpired,
        step: ReportStep.photo,
      );
    case 'CATEGORY_INACTIVE':
      return ReportErrorView(l10n.errorCategoryInactive, step: ReportStep.what);
    case 'WARD_CONFIRMATION_REQUIRED':
      return ReportErrorView(
        l10n.reportErrorWardConfirmation,
        step: ReportStep.photo,
      );
    case 'OUTSIDE_SERVICE_AREA':
      return ReportErrorView(
        l10n.reportFlowOutsideArea,
        step: ReportStep.photo,
      );
    case 'RATE_LIMITED':
      final quota = e.details.any((d) => d.issue == 'issues_per_day');
      return ReportErrorView(
        quota ? l10n.reportFlowQuota(quotaPerDay) : appErrorMessage(l10n, e),
      );
    case 'OWN_ISSUE':
      return ReportErrorView(l10n.reportErrorOwnIssue);
    case 'ISSUE_NOT_OPEN':
      return ReportErrorView(l10n.reportErrorNotOpen);
    case 'ACCOUNT_SUSPENDED':
      return ReportErrorView(l10n.reportErrorSuspended);
    case 'VALIDATION_FAILED':
      final field = e.details.isEmpty ? '' : e.details.first.field;
      final step = switch (field) {
        'description' || 'structuredReason' => ReportStep.details,
        'photoIds' || 'deviceCapturedAt' => ReportStep.photo,
        _ => null,
      };
      return ReportErrorView(l10n.errorValidationFailed, step: step);
    default:
      return ReportErrorView(appErrorMessage(l10n, e));
  }
}
