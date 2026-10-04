import { randomBytes } from 'node:crypto';
import jwt from 'jsonwebtoken';
import {
  checkIdTokenClaims,
  FirebaseTokenError,
  FirebaseUnavailableError,
  type FirebaseGateway,
  type VerifiedPhoneIdentity,
} from './types';

export interface FakeTokenOptions {
  uid: string;
  phone?: string | null;
  provider?: string;
  /** Override the audience (default: the project id). */
  aud?: string;
  /** Override the issuer (default: the securetoken URL of the project). */
  iss?: string;
  /** Seconds from now until expiry (negative = already expired). Default 3600. */
  expiresInS?: number;
}

/**
 * Test double (TASK-04 §6 step 4). Tokens are real JWTs signed with a per-instance secret, so the shared
 * claim checks run exactly as for the other gateways. Can simulate revoked users and an outage, and records
 * deleteUser calls.
 */
export class FakeFirebaseGateway implements FirebaseGateway {
  readonly mode = 'fake' as const;
  readonly deletedUids: string[] = [];
  readonly revokedUids = new Set<string>();
  unavailable = false;
  private readonly secret = randomBytes(32);

  constructor(readonly projectId = 'demo-saarthee') {}

  issueToken(opts: FakeTokenOptions): string {
    const now = Math.floor(Date.now() / 1000);
    const claims: Record<string, unknown> = {
      aud: opts.aud ?? this.projectId,
      iss: opts.iss ?? `https://securetoken.google.com/${this.projectId}`,
      sub: opts.uid,
      iat: now - 5,
      auth_time: now - 5,
      exp: now + (opts.expiresInS ?? 3600),
      firebase: { sign_in_provider: opts.provider ?? 'phone' },
    };
    if (opts.phone !== null) claims.phone_number = opts.phone ?? '+919000000001';
    return jwt.sign(claims, this.secret, { algorithm: 'HS256', noTimestamp: true });
  }

  async verifyIdToken(idToken: string): Promise<VerifiedPhoneIdentity> {
    if (this.unavailable) throw new FirebaseUnavailableError('fake-unavailable');
    let claims: jwt.JwtPayload;
    try {
      // Expiry is checked by checkIdTokenClaims so the reason code matches the other gateways.
      claims = jwt.verify(idToken, this.secret, { algorithms: ['HS256'], ignoreExpiration: true }) as jwt.JwtPayload;
    } catch {
      throw new FirebaseTokenError('malformed');
    }
    const identity = checkIdTokenClaims(claims, this.projectId);
    if (this.revokedUids.has(identity.uid)) throw new FirebaseTokenError('revoked');
    return identity;
  }

  async deleteUser(uid: string): Promise<void> {
    if (this.unavailable) throw new FirebaseUnavailableError('fake-unavailable');
    this.deletedUids.push(uid);
  }
}
