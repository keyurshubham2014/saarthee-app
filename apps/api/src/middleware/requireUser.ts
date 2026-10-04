import type { NextFunction, Request, RequestHandler } from 'express';
import type { AppLanguage, UserRole } from '@prisma/client';
import { z } from 'zod';
import { prisma } from '../lib/db';
import { AppError } from '../lib/errors';
import { verifyUserToken } from '../lib/tokens';

export interface AuthenticatedUser {
  id: string;
  role: UserRole;
  language: AppLanguage;
  homeWardId: string | null;
}

declare module 'express-serve-static-core' {
  interface Request {
    user?: AuthenticatedUser;
  }
}

const uuid = z.uuid();

/**
 * Resolves the citizen behind a Bearer token (TASK-04 §5.3): HS256 + iss + aud = USER_JWT_AUDIENCE + typ user
 * → user exists, status active and tv equal. Expired → TOKEN_EXPIRED; version mismatch, deleted or any
 * other failure → TOKEN_REVOKED; suspended → ACCOUNT_SUSPENDED.
 */
async function authenticate(token: string): Promise<AuthenticatedUser> {
  const result = verifyUserToken(token);
  if (result.status === 'expired') throw new AppError('TOKEN_EXPIRED');
  if (result.status !== 'ok' || !uuid.safeParse(result.userId).success) throw new AppError('TOKEN_REVOKED');
  const user = await prisma.user.findUnique({
    where: { id: result.userId },
    select: { id: true, role: true, language: true, homeWardId: true, status: true, tokenVersion: true },
  });
  if (!user || user.status === 'deleted' || user.tokenVersion !== result.tokenVersion) throw new AppError('TOKEN_REVOKED');
  if (user.status === 'suspended') throw new AppError('ACCOUNT_SUSPENDED');
  return { id: user.id, role: user.role, language: user.language, homeWardId: user.homeWardId };
}

function bearer(req: Request): string | null | undefined {
  const header = req.header('authorization');
  if (header === undefined) return undefined;
  const match = /^Bearer ([A-Za-z0-9._-]+)$/.exec(header);
  return match?.[1] ?? null;
}

function run(req: Request, next: NextFunction, token: string) {
  authenticate(token).then(
    (user) => {
      req.user = user;
      next();
    },
    (err: unknown) => next(err),
  );
}

/** Citizen guard: no/invalid token → 401. */
export const requireUser: RequestHandler = (req, _res, next) => {
  const token = bearer(req);
  if (token === undefined) return next(new AppError('AUTH_REQUIRED'));
  if (token === null) return next(new AppError('TOKEN_REVOKED'));
  run(req, next, token);
};

/** Sets req.user when a valid token is present; no header → anonymous; an invalid token → 401. */
export const optionalUser: RequestHandler = (req, _res, next) => {
  const token = bearer(req);
  if (token === undefined) return next();
  if (token === null) return next(new AppError('TOKEN_REVOKED'));
  run(req, next, token);
};

/** Role guard (use after requireUser): other roles → 403 FORBIDDEN. */
export function requireRole(...roles: UserRole[]): RequestHandler {
  return (req, _res, next) => {
    if (!req.user) return next(new AppError('AUTH_REQUIRED'));
    if (!roles.includes(req.user.role)) return next(new AppError('FORBIDDEN'));
    next();
  };
}
