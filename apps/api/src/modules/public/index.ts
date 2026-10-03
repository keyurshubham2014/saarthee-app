import { Router } from 'express';
import { z } from 'zod';
import { AppError } from '../../lib/errors';
import { rateLimit } from '../../middleware/rateLimit';
import { validate } from '../../middleware/validate';
import { databaseReachable } from './health.service';
import { validateInviteCode } from './invite.service';
import { listActiveCategories } from './categories.service';

export const publicRouter = Router();

// 03 §10: GET /health and GET /categories share one 120 per IP per minute budget.
const healthCategoriesLimiter = rateLimit({ windowMs: 60_000, max: 120 });
// 03 §10: POST /invite-codes/validate 30 per IP per hour.
const inviteLimiter = rateLimit({ windowMs: 60 * 60_000, max: 30 });

publicRouter.get('/health', healthCategoriesLimiter, async (_req, res) => {
  if (!(await databaseReachable())) throw new AppError('SERVICE_UNAVAILABLE');
  res.json({ status: 'ok', db: 'ok' });
});

publicRouter.get('/categories', healthCategoriesLimiter, async (_req, res) => {
  res.json({ items: await listActiveCategories() });
});

const inviteBody = z.object({
  code: z
    .string()
    .trim()
    .regex(/^[A-Za-z0-9]{6,20}$/, 'Use 6 to 20 letters or digits.'),
});

publicRouter.post('/invite-codes/validate', inviteLimiter, validate({ body: inviteBody }), async (req, res) => {
  const { code } = req.body as z.infer<typeof inviteBody>;
  res.json(await validateInviteCode(code));
});
