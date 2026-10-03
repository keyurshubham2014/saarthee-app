import type { RequestHandler } from 'express';
import { z } from 'zod';
import { loadAdminForToken } from '../lib/adminAuth';
import { AppError } from '../lib/errors';
import { verifyAdminToken } from '../lib/tokens';

const uuid = z.uuid();

/**
 * Admin JWT guard (03 §3.1): Bearer header → signature/exp/iss/aud → admin exists, active and tv matches.
 * Expired → TOKEN_EXPIRED; anything else → TOKEN_REVOKED (TASK-05 §5.6).
 */
export const requireAdmin: RequestHandler = async (req, _res, next) => {
  const header = req.header('authorization');
  const match = header ? /^Bearer ([A-Za-z0-9._-]+)$/.exec(header) : null;
  if (!match?.[1]) return next(new AppError('TOKEN_REVOKED'));
  const result = verifyAdminToken(match[1]);
  if (result.status === 'expired') return next(new AppError('TOKEN_EXPIRED'));
  if (result.status !== 'ok' || !uuid.safeParse(result.adminId).success) return next(new AppError('TOKEN_REVOKED'));
  const admin = await loadAdminForToken(result.adminId, result.tokenVersion);
  if (!admin) return next(new AppError('TOKEN_REVOKED'));
  req.admin = admin;
  next();
};
