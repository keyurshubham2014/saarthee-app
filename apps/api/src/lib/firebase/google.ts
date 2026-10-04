import type { App } from 'firebase-admin/app';
import { config } from '../../config';
import {
  checkIdTokenClaims,
  FirebaseTokenError,
  FirebaseUnavailableError,
  type FirebaseGateway,
  type VerifiedPhoneIdentity,
} from './types';

let app: App | undefined;

/**
 * The single firebase-admin app (auth + FCM), created on first use from the service account at
 * GOOGLE_APPLICATION_CREDENTIALS. Loaded lazily so tests and log/memory drivers never import firebase-admin.
 */
export function firebaseAdminApp(): App {
  if (app) return app;
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const { initializeApp, applicationDefault } = require('firebase-admin/app') as typeof import('firebase-admin/app');
  app = initializeApp({ credential: applicationDefault(), projectId: config.FIREBASE_PROJECT_ID }, 'saarthee');
  return app;
}

const UNAVAILABLE = new Set(['app/network-error', 'app/network-timeout', 'auth/internal-error', 'app/invalid-credential']);

/** Maps a firebase-admin error to our errors; only the code survives (REQ-S-015). */
function mapError(err: unknown): never {
  const code = typeof (err as { code?: unknown })?.code === 'string' ? (err as { code: string }).code : 'unknown';
  if (err instanceof FirebaseTokenError || err instanceof FirebaseUnavailableError) throw err;
  if (UNAVAILABLE.has(code)) throw new FirebaseUnavailableError(code);
  throw new FirebaseTokenError(code);
}

/** Production gateway: firebase-admin verifies the signature against Google's certs and checks revocation. */
export class GoogleFirebaseGateway implements FirebaseGateway {
  readonly mode = 'google' as const;

  private auth() {
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const { getAuth } = require('firebase-admin/auth') as typeof import('firebase-admin/auth');
    return getAuth(firebaseAdminApp());
  }

  async verifyIdToken(idToken: string): Promise<VerifiedPhoneIdentity> {
    try {
      const decoded = await this.auth().verifyIdToken(idToken, true);
      return checkIdTokenClaims(decoded, config.FIREBASE_PROJECT_ID);
    } catch (err) {
      mapError(err);
    }
  }

  async deleteUser(uid: string): Promise<void> {
    try {
      await this.auth().deleteUser(uid);
    } catch (err) {
      if ((err as { code?: unknown })?.code === 'auth/user-not-found') return;
      mapError(err);
    }
  }
}
