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
