/**
 * Citizen content flagging (TASK-10 §5.3, REQ-F-051): `POST /issues/{id}/flags` for an issue or one of its
 * comments. One open flag per person per target (repeat → 200 with the same flag); 20 flags per IST day.
 */
import { Router } from 'express';
import { Prisma } from '@prisma/client';
import { z } from 'zod';
import { now } from '../../lib/clock';
import { prisma } from '../../lib/db';
import { AppError } from '../../lib/errors';
import { requireUser } from '../../middleware/requireUser';
import { validate } from '../../middleware/validate';

export const flagsRouter = Router();

export const FLAGS_PER_DAY = 20;
const params = z.object({ id: z.uuid() });
const body = z.strictObject({
  reason: z.enum(['spam', 'abusive', 'private_info', 'not_civic', 'wrong_location', 'duplicate', 'other']),
  note: z.string().trim().max(200).optional(),
  eventId: z.uuid().optional(),
});

/** Start of the current Asia/Kolkata calendar day. */
function istDayStart(at: Date): Date {
  const ist = new Date(at.getTime() + 330 * 60_000);
  return new Date(Date.UTC(ist.getUTCFullYear(), ist.getUTCMonth(), ist.getUTCDate()) - 330 * 60_000);
}

flagsRouter.post('/issues/:id/flags', requireUser, validate({ params, body }), async (req, res) => {
  const issueId = (res.locals.params as z.infer<typeof params>).id;
  const input = req.body as z.infer<typeof body>;
  const userId = req.user!.id;
  const issue = await prisma.issue.findUnique({ where: { id: issueId }, select: { visibility: true, reporterId: true } });
  if (!issue || (issue.visibility !== 'public' && issue.reporterId !== userId)) throw new AppError('NOT_FOUND');
  let targetType: 'issue' | 'issue_event' = 'issue';
  let targetId = issueId;
  if (input.eventId) {
    const event = await prisma.issueEvent.findUnique({ where: { id: input.eventId }, select: { issueId: true, type: true } });
    if (!event || event.issueId !== issueId || event.type !== 'comment') throw new AppError('NOT_FOUND');
    targetType = 'issue_event';
    targetId = input.eventId;
  }
  const existing = await prisma.moderationFlag.findFirst({ where: { reporterId: userId, targetType, targetId, status: 'open' }, select: { id: true } });
  if (existing) return void res.status(200).json({ flagId: existing.id, alreadyReported: true });
  const today = await prisma.moderationFlag.count({ where: { reporterId: userId, createdAt: { gte: istDayStart(now()) } } });
  if (today >= FLAGS_PER_DAY) throw new AppError('FLAG_QUOTA');
  try {
    const flag = await prisma.moderationFlag.create({
      data: { targetType, targetId, issueId, reporterId: userId, reason: input.reason, note: input.note || null, createdAt: now() },
    });
    res.status(201).json({ flagId: flag.id, alreadyReported: false });
  } catch (err) {
    // Concurrent duplicate hit the partial unique index: answer with the existing open flag.
    if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') {
      const flag = await prisma.moderationFlag.findFirst({ where: { reporterId: userId, targetType, targetId, status: 'open' } });
      if (flag) return void res.status(200).json({ flagId: flag.id, alreadyReported: true });
    }
    throw err;
  }
});
