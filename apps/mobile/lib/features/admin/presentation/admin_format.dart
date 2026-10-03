import 'package:intl/intl.dart';

import 'admin_l10n.dart';
import '../data/admin_api_error.dart';
import '../data/models/complaint_summary.dart';

const Duration _istOffset = Duration(hours: 5, minutes: 30);

/// Converts any instant to wall-clock IST.
DateTime toIst(DateTime instant) => instant.toUtc().add(_istOffset);

/// "3 Oct 2026, 10:42 am" in IST using the device locale's format.
String formatIstDateTime(DateTime instant, String locale) {
  final ist = toIst(instant);
  return '${DateFormat.yMMMd(locale).format(ist)}, '
      '${DateFormat.jm(locale).format(ist)}';
}

/// "3 Oct" in IST.
String formatIstShortDate(DateTime instant, String locale) =>
    DateFormat.MMMd(locale).format(toIst(instant));

/// Whole days between [instant] and now (never negative).
int daysSince(DateTime instant, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).toUtc().difference(instant.toUtc());
  return diff.isNegative ? 0 : diff.inDays;
}

/// "+91 98765 43210" for Indian numbers; other numbers are returned as is.
String formatPhone(String e164) {
  final digits = e164.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length == 12 && digits.startsWith('91')) {
    return '+91 ${digits.substring(2, 7)} ${digits.substring(7)}';
  }
  return e164;
}

/// Ratio 0..1 as a percentage with at most one decimal place, or null.
String? formatRatePercent(double? ratio, String locale) {
  if (ratio == null) {
    return null;
  }
  final format = NumberFormat.percentPattern(locale)
    ..minimumFractionDigits = 0
    ..maximumFractionDigits = 1;
  return format.format(ratio);
}

/// Distances in whole metres.
String formatMeters(double meters, String locale) =>
    NumberFormat.decimalPattern(locale).format(meters.round());

String sourceLabel(AppLocalizations l10n, String tag) {
  switch (tag) {
    case 'rwa':
      return l10n.adminSourceRwa;
    case 'activist':
      return l10n.adminSourceActivist;
    case 'social':
      return l10n.adminSourceSocial;
    case 'network':
      return l10n.adminSourceNetwork;
    case 'trusted':
      return l10n.adminSourceTrusted;
    default:
      return l10n.adminSourceUnknown;
  }
}

String statusLabel(AppLocalizations l10n, ComplaintStatus status) {
  switch (status) {
    case ComplaintStatus.filed:
      return l10n.adminStatusFiled;
    case ComplaintStatus.reminded:
      return l10n.adminStatusReminded;
    case ComplaintStatus.verifiedFixed:
      return l10n.adminStatusFixed;
    case ComplaintStatus.verifiedNotFixed:
      return l10n.adminStatusNotFixed;
  }
}

String exclusionReasonLabel(AppLocalizations l10n, String reason) {
  switch (reason) {
    case 'test':
      return l10n.adminReasonTest;
    case 'invalid':
      return l10n.adminReasonInvalid;
    case 'duplicate':
      return l10n.adminReasonDuplicate;
    default:
      return l10n.adminReasonOther;
  }
}

/// Maps an admin error to its ARB message, keyed by backend code (03 §9.1).
String adminErrorMessage(AppLocalizations l10n, AdminApiError error) {
  if (error.isNetwork) {
    return l10n.adminOfflineBanner;
  }
  switch (error.code) {
    case AdminErrorCodes.invalidCredentials:
      return l10n.adminErrorInvalidCredentials;
    case AdminErrorCodes.adminDisabled:
      return l10n.adminErrorAdminDisabled;
    case AdminErrorCodes.tokenExpired:
    case AdminErrorCodes.tokenRevoked:
      return l10n.adminSessionEnded;
    case AdminErrorCodes.rateLimited:
      return error.retryAfterSeconds != null
          ? l10n.adminErrorRateLimitedMinutes(error.retryAfterMinutes)
          : l10n.adminErrorRateLimited;
    case AdminErrorCodes.notFound:
      return l10n.adminErrorNotFound;
    case AdminErrorCodes.complaintExcluded:
      return l10n.adminErrorComplaintExcluded;
    case AdminErrorCodes.complaintAnonymized:
      return l10n.adminErrorComplaintAnonymized;
    case AdminErrorCodes.photoDeleted:
      return l10n.adminErrorPhotoDeleted;
    case AdminErrorCodes.inviteCodeTaken:
      return l10n.adminErrorInviteCodeTaken;
    case AdminErrorCodes.validationFailed:
      return l10n.adminErrorValidation;
    case AdminErrorCodes.serviceUnavailable:
      return l10n.adminErrorServiceUnavailable;
    default:
      return l10n.adminErrorGeneric;
  }
}
