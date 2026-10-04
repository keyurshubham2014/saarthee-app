import type { Initiative } from '@prisma/client';
import { Router } from 'express';
import type { z } from 'zod';
import { staffContentAudit } from '../../lib/audit';
import { prisma } from '../../lib/db';
import { AppError } from '../../lib/errors';
import { logger } from '../../lib/logger';
import { notifyUser } from '../../lib/push';
import { requireStaff } from '../../middleware/requireStaff';
import { staffUserId } from './actor';
import { validate } from '../../middleware/validate';
import { attendanceBody, idParams, initiativeCreate, initiativePatch } from './schemas';

/** Staff initiatives API (TASK-12 §5.3): admin only. */
export const staffInitiativesRouter = Router();

// TASK-14 sweep: requireStaff accepts the v1 admin email login like every other /staff route.
const admin = [requireStaff('admin')];

const ALLOWED: Record<string, string[]> = {
  draft: ['published', 'cancelled'],
  published: ['completed', 'cancelled'],
  completed: ['cancelled'],
  cancelled: [],
};

function serialize(i: Initiative) {
  return { ...i, lat: i.lat === null ? null : Number(i.lat), lng: i.lng === null ? null : Number(i.lng) };
}

async function findInitiative(id: string) {
  const i = await prisma.initiative.findUnique({ where: { id } });
  if (!i) throw new AppError('NOT_FOUND');
  return i;
}

function invalid(field: string, issue: string): AppError {
  return new AppError('VALIDATION_FAILED', { details: [{ field, issue }] });
}

/** Tells every `going` citizen that the organiser cancelled (kind `initiative`, channel `updates`). */
async function notifyCancelled(i: Initiative) {
  const going = await prisma.rsvp.findMany({ where: { initiativeId: i.id, status: 'going' }, select: { userId: true } });
  for (const { userId } of going) {
    try {
      await notifyUser(userId, {
        kind: 'initiative',
        refId: i.id,
        route: `/initiatives/${i.id}`,
        channel: 'updates',
        title: { en: `Cancelled: ${i.titleEn}`, gu: `રદ: ${i.titleGu}` },
        body: { en: 'The organiser cancelled this drive.', gu: 'આયોજકે આ કાર્યક્રમ રદ કર્યો છે.' },
      });
    } catch (err) {
      logger.error({ err, initiativeId: i.id }, 'initiative cancel notify failed');
    }
  }
}

staffInitiativesRouter.get('/staff/initiatives', ...admin, async (_req, res) => {
  const rows = await prisma.initiative.findMany({ orderBy: [{ startsAt: 'desc' }, { id: 'asc' }], take: 500 });
  res.json({ items: rows.map(serialize) });
});

staffInitiativesRouter.get('/staff/initiatives/:id', ...admin, validate({ params: idParams }), async (_req, res) => {
  const { id } = res.locals.params as z.infer<typeof idParams>;
  res.json(serialize(await findInitiative(id)));
});

staffInitiativesRouter.post('/staff/initiatives', ...admin, validate({ body: initiativeCreate }), async (req, res) => {
  const body = req.body as z.output<typeof initiativeCreate>;
  const row = await prisma.initiative.create({ data: { ...body, createdById: staffUserId(req), updatedById: staffUserId(req) } });
  staffContentAudit(req, 'initiative.created', 'initiative', row.id, { status: row.status });
  res.status(201).json(serialize(row));
});

staffInitiativesRouter.patch('/staff/initiatives/:id', ...admin, validate({ params: idParams, body: initiativePatch }), async (req, res) => {
  const { id } = res.locals.params as z.infer<typeof idParams>;
  const current = await findInitiative(id);
  const { status, ...fields } = req.body as z.output<typeof initiativePatch>;
  if (status && status !== current.status && !ALLOWED[current.status]?.includes(status)) throw new AppError('INVALID_TRANSITION');
  const next = { ...current, ...fields };
  if (next.endsAt <= next.startsAt) throw invalid('endsAt', 'End must be after the start.');
  if (next.organiser === 'AMC' && !next.sourceUrl) throw invalid('sourceUrl', 'Add the AMC source link.');
  if ((next.lat == null) !== (next.lng == null)) throw invalid('lng', 'Give both latitude and longitude.');
  const row = await prisma.initiative.update({ where: { id }, data: { ...fields, ...(status ? { status } : {}), updatedById: staffUserId(req) } });
  if (status && status !== current.status) {
    staffContentAudit(req, 'initiative.status_changed', 'initiative', id, { from: current.status, to: status });
    if (status === 'cancelled' && current.status === 'published') await notifyCancelled(row);
  } else {
    staffContentAudit(req, 'initiative.updated', 'initiative', id);
  }
  res.json(serialize(row));
});

staffInitiativesRouter.get('/staff/initiatives/:id/rsvps', ...admin, validate({ params: idParams }), async (_req, res) => {
  const { id } = res.locals.params as z.infer<typeof idParams>;
  await findInitiative(id);
  const rows = await prisma.rsvp.findMany({
    where: { initiativeId: id },
    orderBy: { createdAt: 'asc' },
    include: { user: { select: { displayName: true, phoneE164: true } } },
  });
  res.json({
    items: rows.map((r) => ({
      userId: r.userId,
      displayName: r.user.displayName?.trim() || 'Resident',
      phoneLast4: r.user.phoneE164 ? r.user.phoneE164.slice(-4) : null,
      status: r.status,
      createdAt: r.createdAt,
    })),
  });
});

staffInitiativesRouter.post(
  '/staff/initiatives/:id/attendance',
  ...admin,
  validate({ params: idParams, body: attendanceBody }),
  async (req, res) => {
    const { id } = res.locals.params as z.infer<typeof idParams>;
    const { userIds, attended } = req.body as z.infer<typeof attendanceBody>;
    const i = await findInitiative(id);
    if (i.startsAt > new Date()) throw new AppError('INITIATIVE_NOT_STARTED');
    const { count } = await prisma.rsvp.updateMany({
      where: { initiativeId: id, userId: { in: userIds }, status: attended ? 'going' : 'attended' },
      data: attended ? { status: 'attended', attendanceMarkedBy: staffUserId(req) } : { status: 'going', attendanceMarkedBy: null },
    });
    staffContentAudit(req, 'initiative.attendance_marked', 'initiative', id, { updated: count, attended });
    res.json({ updated: count });
  },
);
