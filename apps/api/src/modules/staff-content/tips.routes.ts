import type { Prisma } from '@prisma/client';
import { Router } from 'express';
import type { z } from 'zod';
import { staffContentAudit } from '../../lib/audit';
import { prisma } from '../../lib/db';
import { AppError } from '../../lib/errors';
import { requireStaff } from '../../middleware/requireStaff';
import { staffUserId } from './actor';
import { validate } from '../../middleware/validate';
import { idParams, tipCreate, tipPatch } from './schemas';

/** Staff seasonal tips API (TASK-12 §5.3, REQ-F-061): admin only. */
export const staffTipsRouter = Router();

// TASK-14 sweep: requireStaff accepts the v1 admin email login like every other /staff route.
const admin = [requireStaff('admin')];

const include = { service: { select: { slug: true } } } as const;
type TipRow = Prisma.ServiceTipGetPayload<{ include: typeof include }>;

const ymd = (d: Date) => d.toISOString().slice(0, 10);

function serialize({ service, ...t }: TipRow) {
  return { ...t, activeFrom: ymd(t.activeFrom), activeTo: ymd(t.activeTo), serviceSlug: service?.slug ?? null };
}

/** Resolves `serviceSlug` to a service id (null clears the link; undefined leaves it). */
async function serviceId(slug: string | null | undefined): Promise<string | null | undefined> {
  if (slug === undefined || slug === null) return slug;
  const s = await prisma.service.findUnique({ where: { slug }, select: { id: true } });
  if (!s) throw new AppError('VALIDATION_FAILED', { details: [{ field: 'serviceSlug', issue: 'No service has that short name.' }] });
  return s.id;
}

staffTipsRouter.get('/staff/tips', ...admin, async (_req, res) => {
  const rows = await prisma.serviceTip.findMany({ include, orderBy: [{ activeFrom: 'desc' }, { id: 'asc' }], take: 500 });
  res.json({ items: rows.map(serialize) });
});

staffTipsRouter.post('/staff/tips', ...admin, validate({ body: tipCreate }), async (req, res) => {
  const { serviceSlug, ...body } = req.body as z.output<typeof tipCreate>;
  const row = await prisma.serviceTip.create({
    data: { ...body, serviceId: (await serviceId(serviceSlug)) ?? null, createdById: staffUserId(req) },
    include,
  });
  staffContentAudit(req, 'tip.created', 'tip', row.id);
  res.status(201).json(serialize(row));
});

staffTipsRouter.patch('/staff/tips/:id', ...admin, validate({ params: idParams, body: tipPatch }), async (req, res) => {
  const { id } = res.locals.params as z.infer<typeof idParams>;
  const current = await prisma.serviceTip.findUnique({ where: { id } });
  if (!current) throw new AppError('NOT_FOUND');
  const { serviceSlug, ...fields } = req.body as z.output<typeof tipPatch>;
  const from = fields.activeFrom ?? current.activeFrom;
  const to = fields.activeTo ?? current.activeTo;
  if (to < from) throw new AppError('VALIDATION_FAILED', { details: [{ field: 'activeTo', issue: 'End date must be on or after the start date.' }] });
  const sid = await serviceId(serviceSlug);
  const row = await prisma.serviceTip.update({ where: { id }, data: { ...fields, ...(sid !== undefined ? { serviceId: sid } : {}) }, include });
  staffContentAudit(req, 'tip.updated', 'tip', id);
  res.json(serialize(row));
});

staffTipsRouter.delete('/staff/tips/:id', ...admin, validate({ params: idParams }), async (req, res) => {
  const { id } = res.locals.params as z.infer<typeof idParams>;
  const { count } = await prisma.serviceTip.deleteMany({ where: { id } });
  if (count === 0) throw new AppError('NOT_FOUND');
  staffContentAudit(req, 'tip.deleted', 'tip', id);
  res.status(204).end();
});
