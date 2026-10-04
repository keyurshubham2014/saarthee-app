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
