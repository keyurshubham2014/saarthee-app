import { Prisma } from '@prisma/client';
import { Router } from 'express';
import type { z } from 'zod';
import { staffContentAudit } from '../../lib/audit';
import { prisma } from '../../lib/db';
import { AppError } from '../../lib/errors';
import { rateLimit } from '../../middleware/rateLimit';
import { requireStaff } from '../../middleware/requireStaff';
import { validate } from '../../middleware/validate';
import { checkServiceLink } from '../services/link-check';
import { idParams, serviceCreate, servicePatch, staffServicesQuery } from './schemas';

/** Staff services API (TASK-12 §5.3): admin edits; moderators read and re-check links. */
export const staffServicesRouter = Router();

const linkCheckLimiter = rateLimit({ windowMs: 3_600_000, max: 10, keyGenerator: (req) => `linkcheck:${req.staff?.actorId ?? 'anon'}` });

export function isUniqueViolation(err: unknown): boolean {
  return err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002';
}

async function findService(id: string) {
  const s = await prisma.service.findUnique({ where: { id } });
  if (!s) throw new AppError('NOT_FOUND');
  return s;
}

staffServicesRouter.get('/staff/services', requireStaff('admin', 'moderator'), validate({ query: staffServicesQuery }), async (_req, res) => {
  const q = res.locals.query as z.infer<typeof staffServicesQuery>;
  const where: Prisma.ServiceWhereInput = {};
  if (q.linkOk) where.linkOk = q.linkOk === 'true';
  if (q.active) where.isActive = q.active === 'true';
  const items = await prisma.service.findMany({ where, orderBy: [{ category: 'asc' }, { sortOrder: 'asc' }, { slug: 'asc' }] });
  res.json({ items });
});

staffServicesRouter.post('/staff/services', requireStaff('admin'), validate({ body: serviceCreate }), async (req, res) => {
  const body = req.body as z.output<typeof serviceCreate>;
  try {
    const row = await prisma.service.create({ data: body });
    staffContentAudit(req, 'service.created', 'service', row.id);
    res.status(201).json(row);
  } catch (err) {
    if (isUniqueViolation(err)) throw new AppError('SLUG_TAKEN', { details: [{ field: 'slug', issue: 'That short name is already used.' }] });
    throw err;
  }
});

staffServicesRouter.patch(
  '/staff/services/:id',
  requireStaff('admin'),
  validate({ params: idParams, body: servicePatch }),
  async (req, res) => {
    const { id } = res.locals.params as z.infer<typeof idParams>;
    await findService(id);
    const { markVerified, ...fields } = req.body as z.output<typeof servicePatch>;
    try {
      const row = await prisma.service.update({ where: { id }, data: { ...fields, ...(markVerified ? { verifiedAt: new Date() } : {}) } });
      staffContentAudit(req, 'service.updated', 'service', id, markVerified ? { markVerified: true } : undefined);
      res.json(row);
    } catch (err) {
      if (isUniqueViolation(err)) throw new AppError('SLUG_TAKEN', { details: [{ field: 'slug', issue: 'That short name is already used.' }] });
      throw err;
    }
  },
);

staffServicesRouter.delete('/staff/services/:id', requireStaff('admin'), validate({ params: idParams }), async (req, res) => {
  const { id } = res.locals.params as z.infer<typeof idParams>;
  await findService(id);
  await prisma.service.update({ where: { id }, data: { isActive: false } });
  staffContentAudit(req, 'service.deactivated', 'service', id);
  res.status(204).end();
});

staffServicesRouter.post(
  '/staff/services/:id/link-check',
  requireStaff('admin', 'moderator'),
  linkCheckLimiter,
  validate({ params: idParams }),
  async (req, res) => {
    const { id } = res.locals.params as z.infer<typeof idParams>;
    const s = await findService(id);
    const result = await checkServiceLink(s.id, s.url, linkCheckOptions());
    staffContentAudit(req, 'service.link_checked', 'service', id, { linkOk: result.linkOk });
    res.json(result);
  },
);

/** Overridable in tests (no network). */
let overrides: Parameters<typeof checkServiceLink>[2] = {};
export function setLinkCheckOptions(o: Parameters<typeof checkServiceLink>[2]): void {
  overrides = o ?? {};
}
function linkCheckOptions() {
  return overrides;
}
