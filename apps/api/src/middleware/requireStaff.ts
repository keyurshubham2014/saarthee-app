import type { RequestHandler } from 'express';
import type { UserRole } from '@prisma/client';
import { z } from 'zod';
import { loadAdminForToken } from '../lib/adminAuth';
import { prisma } from '../lib/db';
import { AppError } from '../lib/errors';
import { verifyAdminToken, verifyUserToken } from '../lib/tokens';

export type StaffRole = Exclude<UserRole, 'citizen'>;

/** Staff identity contract (TASK-08 §5.5, shared with TASK-09/10/11). */
export interface StaffIdentity {
  actorId: string;
  actorKind: 'user' | 'admin_user';
  role: StaffRole;
  /** Wards a representative serves (filled by TASK-09/11); empty for moderators and admins. */
  wardIds: string[];
}

declare module 'express-serve-static-core' {
  interface Request {
    staff?: StaffIdentity;
  }
}

const uuid = z.uuid();

/**
 * Staff guard: accepts a v2 user token (current DB role, status active, token version) or a v1 admin JWT
 * (treated as role `admin`, actorKind `admin_user`). No token → 401 AUTH_REQUIRED; bad/expired → 401;
 * suspended → 403 ACCOUNT_SUSPENDED; role not in `roles` → 403 FORBIDDEN. Sets `req.staff`.
 */
export function requireStaff(...roles: StaffRole[]): RequestHandler {
  return (req, _res, next) => {
    const header = req.header('authorization');
    if (header === undefined) return next(new AppError('AUTH_REQUIRED'));
    const token = /^Bearer ([A-Za-z0-9._-]+)$/.exec(header)?.[1];
    if (!token) return next(new AppError('TOKEN_REVOKED'));
    resolve(token).then(
      (staff) => {
        if (!(roles as string[]).includes(staff.role)) return next(new AppError('FORBIDDEN'));
        req.staff = staff as StaffIdentity;
        next();
      },
      (err: unknown) => next(err),
    );
  };
}

async function resolve(token: string): Promise<{ actorId: string; actorKind: 'user' | 'admin_user'; role: UserRole; wardIds: string[] }> {
  const asUser = verifyUserToken(token);
  if (asUser.status === 'ok' && uuid.safeParse(asUser.userId).success) {
    const user = await prisma.user.findUnique({
      where: { id: asUser.userId },
      select: { id: true, role: true, status: true, tokenVersion: true },
    });
    if (!user || user.status === 'deleted' || user.tokenVersion !== asUser.tokenVersion) throw new AppError('TOKEN_REVOKED');
    if (user.status === 'suspended') throw new AppError('ACCOUNT_SUSPENDED');
    return { actorId: user.id, actorKind: 'user', role: user.role, wardIds: [] };
  }
  const asAdmin = verifyAdminToken(token);
  if (asAdmin.status === 'ok' && uuid.safeParse(asAdmin.adminId).success) {
    const admin = await loadAdminForToken(asAdmin.adminId, asAdmin.tokenVersion);
    if (!admin) throw new AppError('TOKEN_REVOKED');
    return { actorId: admin.id, actorKind: 'admin_user', role: 'admin', wardIds: [] };
  }
  if (asUser.status === 'expired' || asAdmin.status === 'expired') throw new AppError('TOKEN_EXPIRED');
  throw new AppError('TOKEN_REVOKED');
}
