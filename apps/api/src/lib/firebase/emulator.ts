import jwt from 'jsonwebtoken';
import {
  checkIdTokenClaims,
  FirebaseTokenError,
  FirebaseUnavailableError,
  type FirebaseGateway,
  type VerifiedPhoneIdentity,
} from './types';

const TIMEOUT_MS = 5_000;

interface EmulatorUser {
  localId?: string;
  disabled?: boolean;
  validSince?: string;
}

/**
 * Firebase Auth Emulator gateway (local development only; refused in production by config).
 * Emulator ID tokens are unsigned (alg "none"), so only the claims are checked — the same rules as Google
 * tokens — plus a lookup on the emulator for disabled/revoked users. Start the emulator with
 * `npx firebase-tools emulators:start --only auth --project demo-saarthee` (docs/v2/firebase-setup.md).
 */
export class EmulatorFirebaseGateway implements FirebaseGateway {
  readonly mode = 'emulator' as const;

  constructor(
    private readonly host: string,
    private readonly projectId: string,
  ) {}

  private url(action: string): string {
    return `http://${this.host}/identitytoolkit.googleapis.com/v1/projects/${this.projectId}/accounts:${action}`;
  }

  private async call(action: string, body: unknown): Promise<Record<string, unknown>> {
    let res: Response;
    try {
      res = await fetch(this.url(action), {
        method: 'POST',
        headers: { 'content-type': 'application/json', authorization: 'Bearer owner' },
        body: JSON.stringify(body),
        signal: AbortSignal.timeout(TIMEOUT_MS),
      });
    } catch {
      throw new FirebaseUnavailableError('emulator-unreachable');
    }
    const json = (await res.json().catch(() => ({}))) as Record<string, unknown>;
    if (res.status >= 500) throw new FirebaseUnavailableError(`emulator-${res.status}`);
    if (!res.ok) {
      const message = (json.error as { message?: unknown } | undefined)?.message;
      throw new FirebaseTokenError(typeof message === 'string' && /^[A-Z_]{3,60}$/.test(message) ? message.toLowerCase() : 'emulator-rejected');
    }
    return json;
  }

  async verifyIdToken(idToken: string): Promise<VerifiedPhoneIdentity> {
    const decoded = jwt.decode(idToken, { complete: true });
    if (!decoded || typeof decoded.payload === 'string') throw new FirebaseTokenError('malformed');
    const identity = checkIdTokenClaims(decoded.payload, this.projectId);
    const lookup = await this.call('lookup', { localId: [identity.uid] });
    const user = (lookup.users as EmulatorUser[] | undefined)?.[0];
    if (!user) throw new FirebaseTokenError('user-not-found');
    if (user.disabled) throw new FirebaseTokenError('user-disabled');
    if (user.validSince && Number(user.validSince) > identity.authTime) throw new FirebaseTokenError('revoked');
    return identity;
  }

  async deleteUser(uid: string): Promise<void> {
    try {
      await this.call('delete', { localId: uid });
    } catch (err) {
      if (err instanceof FirebaseTokenError && err.code === 'user_not_found') return;
      throw err;
    }
  }
}
