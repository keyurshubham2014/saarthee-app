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
    // Citizen tokens carry typ "user" (TASK-04) and a different audience; never accept them here.
    if (payload.typ !== undefined) return { status: 'invalid' };
    return { status: 'ok', adminId: payload.sub, tokenVersion: payload.tv as number };
  } catch (err) {
    if (err instanceof jwt.TokenExpiredError) return { status: 'expired' };
    return { status: 'invalid' };
  }
}

export interface UserTokenSubject {
  id: string;
  tokenVersion: number;
  role: string;
}

export type UserVerifyResult =
  | { status: 'ok'; userId: string; tokenVersion: number }
  | { status: 'expired' }
  | { status: 'invalid' };

/** Citizen session JWT (TASK-04 §5.2): HS256, sub, tv, role, typ "user", iss, aud = USER_JWT_AUDIENCE. */
export function signUserToken(user: UserTokenSubject): { accessToken: string; expiresAt: Date } {
  const accessToken = jwt.sign({ tv: user.tokenVersion, role: user.role, typ: 'user' }, config.JWT_SECRET, {
    algorithm: 'HS256',
    subject: user.id,
    issuer: config.JWT_ISSUER,
    audience: config.USER_JWT_AUDIENCE,
    expiresIn: config.USER_JWT_EXPIRES_IN as jwt.SignOptions['expiresIn'],
  });
  const decoded = jwt.decode(accessToken) as { exp: number };
  return { accessToken, expiresAt: new Date(decoded.exp * 1000) };
}

/** Verifies a citizen token: HS256, expiry, issuer, the user audience and typ "user". */
export function verifyUserToken(token: string): UserVerifyResult {
  try {
    const payload = jwt.verify(token, config.JWT_SECRET, {
      algorithms: ['HS256'],
      issuer: config.JWT_ISSUER,
      audience: config.USER_JWT_AUDIENCE,
    });
    if (typeof payload === 'string' || typeof payload.sub !== 'string' || !Number.isInteger(payload.tv)) {
      return { status: 'invalid' };
    }
    if (payload.typ !== 'user') return { status: 'invalid' };
    return { status: 'ok', userId: payload.sub, tokenVersion: payload.tv as number };
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
