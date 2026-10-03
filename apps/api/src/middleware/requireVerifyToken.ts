import type { RequestHandler } from 'express';
import { resolveVerifyToken } from '../lib/verifyToken';

/** Verify-token guard: the token is read ONLY from the X-Verify-Token header, never from URL or body. */
export const requireVerifyToken: RequestHandler = async (req, _res, next) => {
  req.verify = await resolveVerifyToken(req.header('x-verify-token'), req.id);
  next();
};
