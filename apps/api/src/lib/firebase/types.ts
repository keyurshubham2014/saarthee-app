/**
 * Firebase boundary (TASK-04 §6 step 4). Everything that talks to Firebase Authentication goes through
 * FirebaseGateway so the API runs against Google (production), the Auth Emulator (local) or a fake (tests).
 * Errors carry a short code only — never the token, the phone number or the library's message.
 */
export interface VerifiedPhoneIdentity {
  uid: string;
  /** E.164, e.g. +919000000001. Never log it. */
  phoneE164: string;
  authTime: number;
}

export interface FirebaseGateway {
  readonly mode: 'google' | 'emulator' | 'fake';
  /** Signature (Google certs, or none on the emulator), aud, iss, exp/iat/auth_time, revocation, phone provider. */
  verifyIdToken(idToken: string): Promise<VerifiedPhoneIdentity>;
  /** Deletes the Firebase user; an already-missing user counts as success. */
  deleteUser(uid: string): Promise<void>;
}

/** The token was rejected (→ 401 FIREBASE_TOKEN_INVALID). `code` is safe to log. */
export class FirebaseTokenError extends Error {
  constructor(readonly code: string) {
    super(`firebase token rejected: ${code}`);
  }
}

/** Firebase could not be reached (→ 503 FIREBASE_UNAVAILABLE). */
export class FirebaseUnavailableError extends Error {
  constructor(readonly code: string) {
    super(`firebase unavailable: ${code}`);
  }
}

export interface IdTokenClaims {
  aud?: unknown;
  iss?: unknown;
  sub?: unknown;
  exp?: unknown;
  iat?: unknown;
  auth_time?: unknown;
  phone_number?: unknown;
  firebase?: { sign_in_provider?: unknown } | unknown;
}

const CLOCK_SKEW_S = 300;
const PHONE = /^\+[1-9][0-9]{7,14}$/;

/**
 * Claim rules shared by every gateway (Firebase "Verify ID tokens" + TASK-04 §5.3 step 2):
 * aud = project, iss = securetoken URL, sub = uid (1–128 chars), exp in the future, iat and auth_time not in
 * the future, sign-in provider "phone" with a phone number.
 */
export function checkIdTokenClaims(claims: IdTokenClaims, projectId: string, nowS = Math.floor(Date.now() / 1000)): VerifiedPhoneIdentity {
  if (claims.aud !== projectId) throw new FirebaseTokenError('wrong-audience');
  if (claims.iss !== `https://securetoken.google.com/${projectId}`) throw new FirebaseTokenError('wrong-issuer');
  if (typeof claims.sub !== 'string' || claims.sub.length < 1 || claims.sub.length > 128) {
    throw new FirebaseTokenError('bad-subject');
  }
  if (typeof claims.exp !== 'number' || claims.exp <= nowS) throw new FirebaseTokenError('expired');
  if (typeof claims.iat !== 'number' || claims.iat > nowS + CLOCK_SKEW_S) throw new FirebaseTokenError('bad-iat');
  if (typeof claims.auth_time !== 'number' || claims.auth_time > nowS + CLOCK_SKEW_S) {
    throw new FirebaseTokenError('bad-auth-time');
  }
  const provider = (claims.firebase as { sign_in_provider?: unknown } | undefined)?.sign_in_provider;
  if (provider !== 'phone') throw new FirebaseTokenError('not-phone-provider');
  if (typeof claims.phone_number !== 'string' || !PHONE.test(claims.phone_number)) {
    throw new FirebaseTokenError('no-phone-number');
  }
  return { uid: claims.sub, phoneE164: claims.phone_number, authTime: claims.auth_time };
}
