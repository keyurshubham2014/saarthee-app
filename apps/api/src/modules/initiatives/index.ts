/**
 * Civic initiatives (V2 TASK-12 §5.3, REQ-F-059, REQ-F-060): GET /initiatives, /initiatives/{id},
 * POST/DELETE /initiatives/{id}/rsvp.
 */
import { Router } from 'express';
import { z } from 'zod';
import { rateLimit } from '../../middleware/rateLimit';
import { optionalUser, requireUser } from '../../middleware/requireUser';
import { validate } from '../../middleware/validate';
import { cancelRsvp, getInitiative, listInitiatives, rsvp } from './initiatives.service';
import './privacy';

export const initiativesRouter = Router();

export const INITIATIVE_TYPES = ['tree_drive', 'cleanup', 'health_camp', 'other'] as const;

const limiter = rateLimit({ windowMs: 60_000, max: 120 });
const rsvpLimiter = rateLimit({ windowMs: 86_400_000, max: 30, keyGenerator: (req) => `rsvp:${req.user?.id ?? 'anon'}` });

const listQuery = z.object({
  ward: z.uuid().optional(),
  upcoming: z.enum(['true', 'false']).default('true').transform((v) => v === 'true'),
  type: z.enum(INITIATIVE_TYPES).optional(),
  cursor: z.string().max(200).optional(),
  limit: z.coerce.number().int().min(1).max(20).default(20),
});

const idParams = z.object({ id: z.uuid() });

initiativesRouter.get('/initiatives', limiter, optionalUser, validate({ query: listQuery }), async (req, res) => {
  res.json(await listInitiatives(res.locals.query as z.infer<typeof listQuery>, req.user?.id));
});

initiativesRouter.get('/initiatives/:id', limiter, optionalUser, validate({ params: idParams }), async (req, res) => {
  const { id } = res.locals.params as z.infer<typeof idParams>;
  res.json(await getInitiative(id, req.user));
});

initiativesRouter.post('/initiatives/:id/rsvp', requireUser, rsvpLimiter, validate({ params: idParams }), async (req, res) => {
  const { id } = res.locals.params as z.infer<typeof idParams>;
  res.json(await rsvp(id, req.user!.id));
});

initiativesRouter.delete('/initiatives/:id/rsvp', requireUser, rsvpLimiter, validate({ params: idParams }), async (req, res) => {
  const { id } = res.locals.params as z.infer<typeof idParams>;
  res.json(await cancelRsvp(id, req.user!.id));
});
