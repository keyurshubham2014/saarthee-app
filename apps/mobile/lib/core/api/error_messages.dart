import '../l10n/app_localizations.dart';
import 'app_error.dart';

/// Maps an [AppError] to its ARB message keyed by backend code (02 §9.2).
String appErrorMessage(AppLocalizations l10n, AppError error) {
  switch (error.code) {
    case 'VALIDATION_FAILED':
      return l10n.errorValidationFailed;
    case 'INVITE_CODE_INVALID':
      return l10n.errorInviteCodeInvalid;
    case 'INVITE_CODE_TAKEN':
      return l10n.errorInviteCodeTaken;
    case 'CATEGORY_INACTIVE':
      return l10n.errorCategoryInactive;
    case 'PHOTO_UNUSABLE':
      return l10n.errorPhotoUnusable;
    case 'PHOTO_TOO_LARGE':
      return l10n.errorPhotoTooLarge;
    case 'PHOTO_TYPE_UNSUPPORTED':
      return l10n.errorPhotoTypeUnsupported;
    case 'PHOTO_DELETED':
      return l10n.errorPhotoDeleted;
    case 'VERIFY_TOKEN_INVALID':
      return l10n.errorVerifyTokenInvalid;
    case 'VERIFY_TOKEN_REVOKED':
      return l10n.errorVerifyTokenRevoked;
    case 'INVALID_CREDENTIALS':
      return l10n.errorInvalidCredentials;
    case 'ADMIN_DISABLED':
      return l10n.errorAdminDisabled;
    case 'TOKEN_EXPIRED':
    case 'TOKEN_REVOKED':
      return l10n.errorSessionEnded;
    case 'COMPLAINT_EXCLUDED':
      return l10n.errorComplaintExcluded;
    case 'COMPLAINT_ANONYMIZED':
      return l10n.errorComplaintAnonymized;
    case 'NOT_FOUND':
      return l10n.errorNotFound;
    case 'RATE_LIMITED':
      return rateLimitMessage(l10n, error.retryAfter);
    case 'SERVICE_UNAVAILABLE':
      return l10n.errorServiceUnavailable;
    case 'IDEMPOTENCY_KEY_REUSED':
      return l10n.errorIdempotencyReused;
    case 'CCRS_NOT_LINKED':
      return l10n.errorCcrsNotLinked;
    case AppError.offlineCode:
      return l10n.errorOffline;
    case AppError.timeoutCode:
      return l10n.errorTimeout;
    default:
      return l10n.errorInternal;
  }
}

/// "Try again in N minutes" from Retry-After, or the generic wait message.
String rateLimitMessage(AppLocalizations l10n, Duration? retryAfter) {
  if (retryAfter == null || retryAfter.inSeconds <= 0) {
    return l10n.errorRateLimited;
  }
  if (retryAfter.inSeconds < 60) {
    return l10n.errorRateLimitedSeconds(retryAfter.inSeconds);
  }
  final minutes = (retryAfter.inSeconds / 60).ceil();
  return l10n.errorRateLimitedMinutes(minutes);
}
