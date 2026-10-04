import { Router } from 'express';
import { endpointRetired } from '../../middleware/endpointRetired';
import { rateLimit } from '../../middleware/rateLimit';

export const verifyRouter = Router();

// 03 §10: all /verify/* share 60 per IP per hour.
const verifyLimiter = rateLimit({ windowMs: 60 * 60_000, max: 60 });

// v1 WhatsApp verify-link flow retired in v2 (Spec D11, V2 TASK-01 §5.3): every method and sub-path
// returns 410. v2 verification is POST /issues/{id}/verifications (TASK-06).
verifyRouter.use('/verify', verifyLimiter, endpointRetired);
