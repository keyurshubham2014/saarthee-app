import { Router } from 'express';
import { ipKeyGenerator } from 'express-rate-limit';
import { z } from 'zod';
import { auditLog } from '../../lib/audit';
import { emailHash } from '../../lib/tokens';
import { rateLimit } from '../../middleware/rateLimit';
import { validate } from '../../middleware/validate';
import { login, logoutAll } from './auth.service';

/** Public login route (mounted at the API root). */
export const adminLoginRouter = Router();
/** Routes that sit behind requireAdmin (mounted on the /admin sub-router). */
export const adminAuthRouter = Router();

const loginEmail = (req: { body?: unknown }) => {
  const email = (req.body as { email?: unknown } | undefined)?.email;
  return typeof email === 'string' ? email.trim().toLowerCase() : '';
};

// 03 §10: 5 failed logins per IP + email per 15 minutes; successful logins are not counted.
const loginLimiter = rateLimit({
  windowMs: 15 * 60_000,
  max: 5,
  skipSuccessfulRequests: true,
  keyGenerator: (req) => `${ipKeyGenerator(req.ip ?? 'unknown')}|${emailHash(loginEmail(req))}`,
  logContext: (req) => ({ emailHash: emailHash(loginEmail(req)) }),
});

const loginBody = z.object({
  email: z.email().max(255),
  password: z.string().min(1).max(1024),
});

adminLoginRouter.post('/admin/auth/login', loginLimiter, validate({ body: loginBody }), async (req, res) => {
  const { email, password } = req.body as z.infer<typeof loginBody>;
  res.json(await login(email, password, req.id));
});

adminAuthRouter.get('/me', (req, res) => {
  const admin = req.admin!;
  res.json({ id: admin.id, email: admin.email, displayName: admin.displayName });
});

adminAuthRouter.post('/auth/logout-all', async (req, res) => {
  await logoutAll(req.admin!.id);
  auditLog(req, 'logout_all', req.admin!.id);
  res.status(204).end();
});
