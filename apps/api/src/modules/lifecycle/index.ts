/**
 * Lifecycle routes (V2 TASK-06 §5.3): status changes, neighbour verification, timeline, "AMC closed it".
 * Every status write goes through transition() (lifecycle.service.ts).
 */
import { Router } from 'express';
import { z } from 'zod';
import { config } from '../../config';
import { prisma } from '../../lib/db';
import { AppError } from '../../lib/errors';
import { logger } from '../../lib/logger';
import { rateLimit } from '../../middleware/rateLimit';
import { optionalUser, requireUser } from '../../middleware/requireUser';
import { validate } from '../../middleware/validate';
import { serializeIssue } from '../issues/derive';
import { markCcrsClosed } from './ccrs.service';
import { listEvents } from './events.service';
import { actorFor, transition } from './lifecycle.service';
import { submitVerification } from './verification.service';

export const lifecycleRouter = Router();

const idParams = z.object({ id: z.uuid() });
const STATUSES = ['reported', 'sent', 'acknowledged', 'in_progress', 'marked_fixed', 'verified', 'reopened', 'rejected', 'merged'] as const;
const round6 = (v: number) => Math.round(v * 1e6) / 1e6;

export const statusBody = z.object({
  to: z.enum(['acknowledged', 'in_progress', 'marked_fixed', 'rejected']),
  note: z.string().trim().max(500).optional().nullable(),
  photoIds: z.array(z.uuid()).max(3).optional(),
  clientActionId: z.uuid(),
  expectedStatus: z.enum(STATUSES),
});

export const verificationBody = z.object({
  clientSubmissionId: z.uuid(),
  answer: z.enum(['fixed', 'not_fixed']),
  photoId: z.uuid(),
  latitude: z.number().min(-90).max(90).transform(round6),
  longitude: z.number().min(-180).max(180).transform(round6),
  gpsAccuracyM: z.number().min(0).max(100_000),
  deviceCapturedAt: z.iso.datetime({ offset: true }),
  note: z.string().trim().max(500).optional().nullable(),
});

const eventsQuery = z.object({ cursor: z.uuid().optional(), limit: z.coerce.number().int().min(1).max(50).default(50) });
const ccrsClosedBody = z.object({ closedAt: z.iso.datetime({ offset: true }).optional() });

const eventsLimiter = rateLimit({ windowMs: 60_000, max: 120 });
const ccrsClosedLimiter = rateLimit({ windowMs: 24 * 60 * 60_000, max: 10, keyGenerator: (req) => `ccrs-closed:${req.user?.id ?? 'anon'}` });

/** QUOTA_STATUS_CHANGES_PER_DAY for citizens (reporters); staff are not limited. */
async function assertStatusQuota(userId: string): Promise<void> {
  const n = await prisma.issueEvent.count({
    where: { actorId: userId, actorRole: 'citizen', type: 'status_change', createdAt: { gt: new Date(Date.now() - 86_400_000) } },
  });
  if (n >= config.QUOTA_STATUS_CHANGES_PER_DAY) {
    throw new AppError('RATE_LIMITED', { message: 'You have reached the daily limit. Please try again later.', details: [{ field: 'quota', issue: 'status_changes_per_day' }] });
  }
}

lifecycleRouter.post('/issues/:id/status', requireUser, validate({ params: idParams, body: statusBody }), async (req, res) => {
  const { id } = res.locals.params as z.infer<typeof idParams>;
  const b = req.body as z.infer<typeof statusBody>;
  const user = req.user!;
  const issue = await prisma.issue.findUnique({ where: { id }, select: { reporterId: true, visibility: true } });
  if (!issue) throw new AppError('NOT_FOUND');
  const actor = actorFor(user, issue);
  if (issue.visibility === 'hidden' && actor.kind === 'citizen') throw new AppError('NOT_FOUND');
  if (actor.kind === 'citizen') throw new AppError('FORBIDDEN_ROLE');
  if (actor.kind === 'reporter') await assertStatusQuota(user.id);
  const r = await transition(id, b.to, actor, { note: b.note, photoIds: b.photoIds, clientActionId: b.clientActionId, expectedStatus: b.expectedStatus });
  if (actor.kind !== 'reporter') logger.info({ requestId: req.id, actorId: user.id, role: user.role, action: 'issue_status_changed', targetId: id, to: b.to }, 'staff_action');
  const e = r.event;
  res.json({
    issue: serializeIssue(r.issue),
    event: { id: e.id, type: e.type, fromStatus: e.fromStatus, toStatus: e.toStatus, note: e.note, createdAt: e.createdAt },
    repeated: r.repeated,
  });
});

lifecycleRouter.post('/issues/:id/verifications', requireUser, validate({ params: idParams, body: verificationBody }), async (req, res) => {
  const { id } = res.locals.params as z.infer<typeof idParams>;
  const r = await submitVerification(req.user!, id, req.body as z.infer<typeof verificationBody>, res);
  res.status(r.created ? 201 : 200).json(r.body);
});

lifecycleRouter.get('/issues/:id/events', eventsLimiter, optionalUser, validate({ params: idParams, query: eventsQuery }), async (req, res) => {
  const { id } = res.locals.params as z.infer<typeof idParams>;
  const q = res.locals.query as z.infer<typeof eventsQuery>;
  res.json(await listEvents(id, req.user, q.cursor, q.limit));
});

lifecycleRouter.post('/issues/:id/ccrs/closed', requireUser, ccrsClosedLimiter, validate({ params: idParams, body: ccrsClosedBody }), async (req, res) => {
  const { id } = res.locals.params as z.infer<typeof idParams>;
  res.json(await markCcrsClosed(req.user!.id, id, (req.body as z.infer<typeof ccrsClosedBody>).closedAt));
});
