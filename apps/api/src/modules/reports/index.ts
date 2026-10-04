import { Router } from 'express';
import { endpointRetired } from '../../middleware/endpointRetired';
import { rateLimit } from '../../middleware/rateLimit';

export const reportsRouter = Router();

// 03 §10: POST /reports 30 per IP per hour (kept so retired-route probing stays limited).
const reportsLimiter = rateLimit({ windowMs: 60 * 60_000, max: 30 });

// v1 citizen write retired in v2 (Spec D11, V2 TASK-01 §5.3); replaced by POST /issues (V2 TASK-05).
reportsRouter.post('/reports', reportsLimiter, endpointRetired);
