import { Router } from 'express';
import { AppError } from '../../lib/errors';
import { endpointRetired } from '../../middleware/endpointRetired';
import { rateLimit } from '../../middleware/rateLimit';
import { checkHealth } from './health.service';

export const publicRouter = Router();

// 03 §10: GET /health and GET /categories share one 120 per IP per minute budget.
const healthCategoriesLimiter = rateLimit({ windowMs: 60_000, max: 120 });
// 03 §10: POST /invite-codes/validate 30 per IP per hour.
const inviteLimiter = rateLimit({ windowMs: 60 * 60_000, max: 30 });

publicRouter.get('/health', healthCategoriesLimiter, async (_req, res) => {
  const health = await checkHealth();
  if (!health) throw new AppError('SERVICE_UNAVAILABLE');
  res.json({ status: 'ok', db: 'up', postgis: health.postgis });
});

// GET /categories moved to modules/categories (v2 shape, V2 TASK-05).

// v1 invite codes are retired from the citizen app (Spec D11, V2 TASK-01 §5.6): 410.
publicRouter.post('/invite-codes/validate', inviteLimiter, endpointRetired);
