/// Kinds of failure an admin API call can end in.
enum AdminErrorKind {
  /// The device could not reach the API (offline, DNS, timeout).
  network,

  /// The API answered with an error body (`{error:{code,...}}`).
  server,

  /// Anything else (bad JSON, unexpected response).
  unknown,
}

/// Typed error for admin API calls, keyed by the backend error `code`
/// (docs/03-backend-spec.md §9.1). Screens map [code] to ARB messages.
class AdminApiError implements Exception {
  const AdminApiError({
    required this.kind,
    this.code,
    this.statusCode,
    this.retryAfterSeconds,
    this.fieldErrors = const <String, String>{},
  });

  const AdminApiError.network() : this(kind: AdminErrorKind.network);

  const AdminApiError.unknown() : this(kind: AdminErrorKind.unknown);

  final AdminErrorKind kind;

  /// Backend error code such as `INVALID_CREDENTIALS`, or null.
  final String? code;
  final int? statusCode;

  /// Parsed `Retry-After` header (seconds) for `RATE_LIMITED`.
  final int? retryAfterSeconds;

  /// `details` of a `VALIDATION_FAILED` response: field -> issue.
  final Map<String, String> fieldErrors;

  bool get isNetwork => kind == AdminErrorKind.network;

  /// True for the two codes that end an admin session (02 §5.3).
  bool get isSessionEnded =>
      code == AdminErrorCodes.tokenExpired ||
      code == AdminErrorCodes.tokenRevoked;

  /// `Retry-After` rounded up to whole minutes (at least 1).
  int get retryAfterMinutes {
    final seconds = retryAfterSeconds ?? 60;
    final minutes = (seconds / 60).ceil();
    return minutes < 1 ? 1 : minutes;
  }

  @override
  String toString() => 'AdminApiError(kind: $kind, code: $code)';
}

/// Backend error codes used by the admin screens.
abstract final class AdminErrorCodes {
  static const validationFailed = 'VALIDATION_FAILED';
  static const invalidCredentials = 'INVALID_CREDENTIALS';
  static const adminDisabled = 'ADMIN_DISABLED';
  static const tokenExpired = 'TOKEN_EXPIRED';
  static const tokenRevoked = 'TOKEN_REVOKED';
  static const rateLimited = 'RATE_LIMITED';
  static const notFound = 'NOT_FOUND';
  static const complaintExcluded = 'COMPLAINT_EXCLUDED';
  static const complaintAnonymized = 'COMPLAINT_ANONYMIZED';
  static const photoDeleted = 'PHOTO_DELETED';
  static const inviteCodeTaken = 'INVITE_CODE_TAKEN';
  static const serviceUnavailable = 'SERVICE_UNAVAILABLE';
  static const internalError = 'INTERNAL_ERROR';
}
