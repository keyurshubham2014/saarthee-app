import { Router } from 'express';
import { z } from 'zod';
import { validate } from '../../middleware/validate';
import { rateLimit } from '../../middleware/rateLimit';
import { clientMeta } from '../../middleware/clientMeta';
import { ingestEvents } from './events.service';

export const eventsRouter = Router();

const eventSchema = z.object({
  name: z.string().min(1).max(50),
  occurredAt: z.iso.datetime({ offset: true }),
  properties: z.record(z.string(), z.unknown()).optional(),
});

const bodySchema = z.object({
  events: z.array(eventSchema).min(1).max(50),
});

// 03 §10: 120 per IP per minute; the app drops events instead of retrying forever.
const eventsLimiter = rateLimit({ windowMs: 60_000, max: 120 });

eventsRouter.post('/events', eventsLimiter, validate({ body: bodySchema }), async (req, res) => {
  const { events } = req.body as z.infer<typeof bodySchema>;
  const accepted = await ingestEvents(events, clientMeta(req));
  res.status(202).json({ accepted });
});
