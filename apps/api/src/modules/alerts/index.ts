import { Router, type Request } from 'express';
import { z } from 'zod';
import { now } from '../../lib/clock';
import { AppError } from '../../lib/errors';
import { rateLimit } from '../../middleware/rateLimit';
import { optionalUser, requireUser } from '../../middleware/requireUser';
import { validate } from '../../middleware/validate';
import { getPublicAlert, listAlerts } from './alerts.service';
import { listInbox, markRead, markReadBody } from './inbox.service';
import {
  deviceSubscriptionsBody,
  getDeviceSubscriptions,
  getUserSubscriptions,
  putDeviceSubscriptions,
  putUserSubscriptions,
  subscriptionsBody,
} from './subscriptions.service';

/** Civic alerts (TASK-08 §5.3): public reads, subscriptions, notification inbox. */
export const alertsRouter = Router();

const MIN = 60_000;
const HOUR = 60 * MIN;
const userKey = (req: Request) => `user:${req.user?.id ?? 'none'}`;
const publicLimiter = rateLimit({ windowMs: MIN, max: 120 });
const userReadLimiter = rateLimit({ windowMs: MIN, max: 120, keyGenerator: userKey });
const userWriteLimiter = rateLimit({ windowMs: HOUR, max: 30, keyGenerator: userKey });
const deviceLimiter = rateLimit({ windowMs: HOUR, max: 30 });

const listQuery = z.object({
  wards: z
    .string()
    .transform((v) => v.split(',').map((s) => s.trim()).filter(Boolean))
    .pipe(z.array(z.uuid()).min(1).max(6)),
  active: z.enum(['true', 'false']).default('true').transform((v) => v === 'true'),
  cursor: z.string().max(400).optional(),
  limit: z.coerce.number().int().min(1).max(50).default(20),
});
const idParams = z.object({ id: z.uuid() });
const installParams = z.object({ installId: z.uuid() });
const pageQuery = z.object({ cursor: z.string().max(400).optional(), limit: z.coerce.number().int().min(1).max(50).default(20) });

alertsRouter.get('/alerts', publicLimiter, validate({ query: listQuery }), async (_req, res) => {
  const q = res.locals.query as z.infer<typeof listQuery>;
  res.json(await listAlerts({ wardIds: [...new Set(q.wards)], active: q.active, cursor: q.cursor, limit: q.limit, now: now() }));
});

alertsRouter.get('/alerts/:id', publicLimiter, validate({ params: idParams }), async (_req, res) => {
  const { id } = res.locals.params as z.infer<typeof idParams>;
  res.json(await getPublicAlert(id, now()));
});

alertsRouter.get('/me/subscriptions', requireUser, userReadLimiter, async (req, res) => {
  res.json(await getUserSubscriptions(req.user!.id, req.user!.homeWardId));
});

alertsRouter.put('/me/subscriptions', requireUser, userWriteLimiter, validate({ body: subscriptionsBody }), async (req, res) => {
  res.json(await putUserSubscriptions(req.user!.id, req.user!.homeWardId, req.body as z.infer<typeof subscriptionsBody>));
});

const visitorOnly = (req: Request) => {
  if (req.user) throw new AppError('SIGNED_IN_USE_ME');
};

alertsRouter.get('/devices/:installId/subscriptions', deviceLimiter, optionalUser, validate({ params: installParams }), async (req, res) => {
  visitorOnly(req);
  res.json(await getDeviceSubscriptions((res.locals.params as z.infer<typeof installParams>).installId));
});

alertsRouter.put(
  '/devices/:installId/subscriptions',
  deviceLimiter,
  optionalUser,
  validate({ params: installParams, body: deviceSubscriptionsBody }),
  async (req, res) => {
    visitorOnly(req);
    const { installId } = res.locals.params as z.infer<typeof installParams>;
    res.json(await putDeviceSubscriptions(installId, req.body as z.infer<typeof deviceSubscriptionsBody>));
  },
);

alertsRouter.get('/me/notifications', requireUser, userReadLimiter, validate({ query: pageQuery }), async (req, res) => {
  const q = res.locals.query as z.infer<typeof pageQuery>;
  res.json(await listInbox({ userId: req.user!.id, language: req.user!.language, cursor: q.cursor, limit: q.limit, now: now() }));
});

alertsRouter.post('/me/notifications/read', requireUser, userReadLimiter, validate({ body: markReadBody }), async (req, res) => {
  res.json({ unreadCount: await markRead(req.user!.id, req.body as z.infer<typeof markReadBody>, now()) });
});
