import { createHash, randomBytes } from 'node:crypto';
import jwt from 'jsonwebtoken';
import { config } from '../../config';

export interface AdminTokenSubject {
  id: string;
  tokenVersion: number;
}

export type VerifyResult =
  | { status: 'ok'; adminId: string; tokenVersion: number }
  | { status: 'expired' }
  | { status: 'invalid' };

/** Signs an admin access token (03 §3.2): HS256, claims sub, tv, iat, exp, iss, aud. */
export function signAdminToken(admin: AdminTokenSubject): { accessToken: string; expiresAt: Date } {
  const accessToken = jwt.sign({ tv: admin.tokenVersion }, config.JWT_SECRET, {
    algorithm: 'HS256',
    subject: admin.id,
    issuer: config.JWT_ISSUER,
    audience: config.JWT_AUDIENCE,
    expiresIn: config.JWT_EXPIRES_IN as jwt.SignOptions['expiresIn'],
  });
  const decoded = jwt.decode(accessToken) as { exp: number };
  return { accessToken, expiresAt: new Date(decoded.exp * 1000) };
}

/** Verifies signature (HS256 only), expiry, issuer and audience. */
export function verifyAdminToken(token: string): VerifyResult {
  try {
    const payload = jwt.verify(token, config.JWT_SECRET, {
      algorithms: ['HS256'],
      issuer: config.JWT_ISSUER,
      audience: config.JWT_AUDIENCE,
    });
    if (typeof payload === 'string' || typeof payload.sub !== 'string' || !Number.isInteger(payload.tv)) {
      return { status: 'invalid' };
    }
    return { status: 'ok', adminId: payload.sub, tokenVersion: payload.tv as number };
  } catch (err) {
    if (err instanceof jwt.TokenExpiredError) return { status: 'expired' };
    return { status: 'invalid' };
  }
}

/** Verify tokens (03 §3.2): 32 CSPRNG bytes, URL-safe; only the SHA-256 hex is ever stored. */
export function newVerifyToken(): { raw: string; hash: string } {
  const raw = randomBytes(32).toString('base64url');
  return { raw, hash: hashVerifyToken(raw) };
}

export function hashVerifyToken(raw: string): string {
  return createHash('sha256').update(raw, 'utf8').digest('hex');
}

/** SHA-256 of a lowercased email, for logs (never the email itself). */
export function emailHash(email: string): string {
  return createHash('sha256').update(email.trim().toLowerCase(), 'utf8').digest('hex');
}
