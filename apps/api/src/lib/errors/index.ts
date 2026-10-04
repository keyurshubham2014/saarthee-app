export const ERROR_CODES = {
  VALIDATION_FAILED: { status: 400, message: 'Please check the highlighted fields.' },
  INVITE_CODE_INVALID: { status: 404, message: "That code didn't work. Check it with whoever shared it." },
  INVITE_CODE_TAKEN: { status: 409, message: 'That code already exists.' },
  CATEGORY_INACTIVE: { status: 422, message: 'Please choose the category again.' },
  PHOTO_UNUSABLE: { status: 422, message: 'Please retake the photo.' },
  PHOTO_TOO_LARGE: { status: 413, message: 'That photo is too large. Please try again.' },
  PHOTO_TYPE_UNSUPPORTED: { status: 415, message: "We couldn't read that photo. Please retake it." },
  PHOTO_DELETED: { status: 410, message: 'This photo was deleted.' },
  VERIFY_TOKEN_INVALID: { status: 401, message: "This link isn't valid. Ask for a new one." },
  VERIFY_TOKEN_REVOKED: { status: 410, message: 'This link is no longer active.' },
  INVALID_CREDENTIALS: { status: 401, message: 'Email or password is incorrect.' },
  ADMIN_DISABLED: { status: 403, message: 'This account is disabled.' },
  TOKEN_EXPIRED: { status: 401, message: 'Your session ended. Please log in again.' },
  TOKEN_REVOKED: { status: 401, message: 'Your session ended. Please log in again.' },
  COMPLAINT_EXCLUDED: { status: 409, message: 'This complaint is excluded.' },
  COMPLAINT_ANONYMIZED: { status: 409, message: "This complaint's personal data was removed." },
  NOT_FOUND: { status: 404, message: 'Not found.' },
  RATE_LIMITED: { status: 429, message: 'Too many attempts. Please wait a moment and try again.' },
  INTERNAL_ERROR: { status: 500, message: 'Something went wrong. Please try again.' },
  SERVICE_UNAVAILABLE: { status: 503, message: 'The service is unavailable. Please try again later.' },
  // v2 (append new codes below; one line per code).
  ENDPOINT_RETIRED: { status: 410, message: 'Please update Saarthee to report issues.' },
  OUTSIDE_SERVICE_AREA: { status: 422, message: "This place is outside Ahmedabad's municipal wards." },
  // TASK-04 (citizen accounts).
  AUTH_REQUIRED: { status: 401, message: 'Please sign in to continue.' },
  FIREBASE_TOKEN_INVALID: { status: 401, message: "We couldn't confirm your sign-in. Please try again." },
  AGE_CONFIRMATION_REQUIRED: { status: 403, message: 'You need to be 18 or older to use an account.' },
  CONSENT_REQUIRED: { status: 422, message: 'Please agree to the terms to continue.' },
  CORE_CONSENT_REQUIRED: { status: 409, message: 'This consent is needed for your account. To withdraw it, delete your account.' },
  ACCOUNT_SUSPENDED: { status: 403, message: 'This account is suspended.' },
  FORBIDDEN: { status: 403, message: "You don't have permission to do this." },
  WARD_NOT_FOUND: { status: 422, message: 'Please choose your ward again.' },
  FIREBASE_UNAVAILABLE: { status: 503, message: 'Sign-in is unavailable right now. Please try again later.' },
  // TASK-09 (representatives, relay, election mode). The relay returns CONSENT_REQUIRED with status 403.
  REP_NO_CONTACT: { status: 422, message: "We don't have an official email for this representative yet." },
  MESSAGE_LANGUAGE: { status: 422, message: "Your message contains words we can't send. Please edit it and try again." },
  REP_DUPLICATE: { status: 409, message: 'This representative is already in the roster.' },
  REP_PERSONAL_NUMBER: { status: 400, message: "Mobile numbers can't be saved here. Use an official office landline." },
  ELECTION_MODE_FROZEN: { status: 409, message: 'Election mode is on. Comments and updates are paused until it ends.' },
  // TASK-05 (issue reporting).
  WARD_CONFIRMATION_REQUIRED: { status: 422, message: 'This spot is just outside ward boundaries. Please confirm the ward.' },
  IDEMPOTENCY_KEY_REUSED: { status: 409, message: 'This submission id was already used.' },
  OWN_ISSUE: { status: 409, message: 'You reported this issue.' },
  ISSUE_NOT_OPEN: { status: 409, message: 'This issue is no longer open.' },
  CCRS_ALREADY_LINKED: { status: 409, message: 'A different number is already linked to this report.' },
  // TASK-08 (civic alerts).
  ALERT_STATE_INVALID: { status: 409, message: "This alert can't be changed in its current state." },
  ALERT_INCOMPLETE: { status: 422, message: 'Fill in both languages and a valid time window first.' },
  ALERT_APPROVALS_MISSING: { status: 409, message: 'This alert still needs approval.' },
  ALERT_ALREADY_APPROVED: { status: 409, message: "You've already approved this alert. Another person must give the second approval." },
  ALERT_SECOND_APPROVER_ADMIN: { status: 403, message: 'The second approval for Warning and Critical alerts must come from an admin.' },
  ALERT_ALREADY_SUPERSEDED: { status: 409, message: 'This alert already has an update.' },
  SIGNED_IN_USE_ME: { status: 409, message: 'You are signed in. Your settings are saved to your account.' },
  // TASK-12 (services and initiatives).
  INITIATIVE_NOT_OPEN: { status: 409, message: 'This drive is not taking RSVPs.' },
  INITIATIVE_FULL: { status: 409, message: 'This drive is full.' },
  INITIATIVE_STARTED: { status: 409, message: 'This drive has already started.' },
  INITIATIVE_NOT_STARTED: { status: 409, message: 'Attendance can be marked once the drive starts.' },
  INVALID_TRANSITION: { status: 409, message: 'That status change is not allowed.' },
  SLUG_TAKEN: { status: 409, message: 'That short name is already used.' },
  // TASK-06 (issue lifecycle; INVALID_TRANSITION above is shared).
  STALE_STATUS: { status: 409, message: 'This issue changed while you were here.' },
  FORBIDDEN_ROLE: { status: 403, message: "You can't change this issue." },
  OUT_OF_WARD: { status: 403, message: 'This issue is outside your ward.' },
  VERIFY_NOT_OPEN: { status: 409, message: 'This issue can no longer be checked.' },
  ALREADY_ANSWERED_TODAY: { status: 409, message: "You've already answered today. Thank you." },
  TOO_FAR_FROM_ISSUE: { status: 422, message: 'You need to be within 100 m of the problem to verify.' },
  LOCATION_TOO_INACCURATE: { status: 422, message: 'Location is approximate. Move into the open and try again.' },
  CCRS_NOT_LINKED: { status: 409, message: 'Link your AMC complaint number first.' },
  // TASK-10 (staff console, moderation).
  WARD_OUT_OF_SCOPE: { status: 403, message: 'This issue is outside your wards.' },
  ISSUE_STATE_INVALID: { status: 409, message: 'This issue was already handled. Reload to see its current state.' },
  MERGE_INVALID: { status: 422, message: "These issues can't be merged." },
  SELF_ROLE_CHANGE: { status: 409, message: "You can't change your own role." },
  SETTING_UNKNOWN: { status: 400, message: 'This setting does not exist.' },
  EXPORT_TOO_LARGE: { status: 413, message: 'Too many rows. Narrow the date range.' },
  FLAG_QUOTA: { status: 429, message: "You've reported a lot today. Please try again tomorrow." },
  SELF_SUSPEND: { status: 409, message: "You can't suspend yourself." },
  USER_STATE_INVALID: { status: 409, message: 'This account is already in that state.' },
  ROLE_CHANGE_INVALID: { status: 422, message: "This person's role can't be changed here." },
  // TASK-07 (discovery).
  WARD_REQUIRED: { status: 400, message: 'Choose a ward to see its feed.' },
  // TASK-11 (representative claims, ward dashboard). WARD_OUT_OF_SCOPE and ELECTION_MODE_FROZEN are shared above.
  CLAIM_ALREADY_PENDING: { status: 409, message: 'You already have a claim waiting for review.' },
  REPRESENTATIVE_ALREADY_VERIFIED: { status: 409, message: 'This profile is already verified. Contact Saarthee if this is wrong.' },
  REPRESENTATIVE_TERM_ENDED: { status: 422, message: 'This term has ended. Claims are open only for the current term.' },
  ROLE_CONFLICT: { status: 409, message: "Staff accounts can't also be representative accounts. Use a separate phone number." },
  CLAIM_NOT_PENDING: { status: 409, message: 'This claim was already decided.' },
  NOT_VERIFIED: { status: 409, message: 'This representative is not verified.' },
  ALREADY_REPLIED: { status: 409, message: 'This message already has a reply.' },
  BAD_SIGNATURE: { status: 401, message: 'Signature check failed.' },
} as const;

export type ErrorCode = keyof typeof ERROR_CODES;

export interface ErrorDetail {
  field: string;
  issue: string;
}

export class AppError extends Error {
  readonly code: ErrorCode;
  readonly status: number;
  readonly details?: ErrorDetail[];

  constructor(code: ErrorCode, opts: { message?: string; details?: ErrorDetail[]; status?: number } = {}) {
    super(opts.message ?? ERROR_CODES[code].message);
    this.code = code;
    this.status = opts.status ?? ERROR_CODES[code].status;
    this.details = opts.details;
  }
}

export function errorBody(err: AppError, requestId: string) {
  return {
    error: {
      code: err.code,
      message: err.message,
      ...(err.details && err.details.length > 0 ? { details: err.details } : {}),
      requestId,
    },
  };
}
