/** POST /issues/{id}/escalations (V2 TASK-06 §5.3, REQ-F-025). */
import { Router } from 'express';
import { z } from 'zod';
import { requireUser } from '../../middleware/requireUser';
import { validate } from '../../middleware/validate';
import { prepareEscalation } from './escalation.service';
import { LEVELS } from './templates';

export const escalationRouter = Router();

const idParams = z.object({ id: z.uuid() });
const body = z.object({ level: z.enum(LEVELS), language: z.enum(['gu', 'en']) });

escalationRouter.post('/issues/:id/escalations', requireUser, validate({ params: idParams, body }), async (req, res) => {
  const { id } = res.locals.params as z.infer<typeof idParams>;
  const b = req.body as z.infer<typeof body>;
  res.json(await prepareEscalation(req.user!, id, b.level, b.language));
});
