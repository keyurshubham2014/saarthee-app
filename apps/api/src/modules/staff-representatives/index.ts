/**
 * Staff roster endpoints (TASK-09 §5.3/§5.5): admin writes, moderator reads; 300 per actor per minute.
 * Election mode does not block admin corrections; every write is audited (ids and counts only).
 */
import { Router } from 'express';
import { z } from 'zod';
import { rateLimit } from '../../middleware/rateLimit';
import { requireRole, requireUser } from '../../middleware/requireUser';
import { validate } from '../../middleware/validate';
import { staffAudit, staffKey } from '../settings';
import {
  createRep, deactivateRep, getRep, listConstituencies, listReps, setWardConstituencies, updateRep, type RepInput,
} from './staff.service';

export const staffRepresentativesRouter = Router();

const limiter = rateLimit({ windowMs: 60_000, max: 300, keyGenerator: staffKey });
const readers = [requireUser, requireRole('admin', 'moderator'), limiter];
const writers = [requireUser, requireRole('admin'), limiter];

const date = z.string().regex(/^\d{4}-\d{2}-\d{2}$/);
const repBody = z.strictObject({
  nameEn: z.string().trim(),
  nameGu: z.string().trim(),
  role: z.enum(['corporator', 'mla', 'mp']),
  partyText: z.string().trim().nullish(),
  termStart: date,
  termEnd: date.nullish(),
  wardNumber: z.number().int().nullish(),
  acNumbers: z.array(z.number().int()).max(20).optional(),
  officePhone: z.string().trim().max(30).nullish(),
  publicEmail: z.string().trim().max(254).nullish(),
  sourceUrl: z.string().trim().max(500),
  lastVerifiedAt: date,
});
const listQuery = z.object({
  ward: z.coerce.number().int().min(1).max(48).optional(),
  role: z.enum(['corporator', 'mla', 'mp']).optional(),
  q: z.string().trim().max(60).optional(),
  active: z.enum(['true', 'false']).transform((v) => v === 'true').optional(),
});
const idParams = z.object({ id: z.uuid() });
const mappingBody = z.strictObject({
  items: z.array(z.strictObject({ acId: z.number().int().positive(), sourceUrl: z.string().regex(/^https:\/\/\S+$/).max(500) })).min(1).max(4),
});

staffRepresentativesRouter.get('/staff/representatives', ...readers, validate({ query: listQuery }), async (_req, res) => {
  res.json({ items: await listReps(res.locals.query as z.infer<typeof listQuery>) });
});

staffRepresentativesRouter.get('/staff/representatives/:id', ...readers, validate({ params: idParams }), async (_req, res) => {
  res.json(await getRep((res.locals.params as z.infer<typeof idParams>).id));
});

staffRepresentativesRouter.post('/staff/representatives', ...writers, validate({ body: repBody }), async (req, res) => {
  const rep = await createRep(req.body as RepInput);
  staffAudit(req, 'rep_created', rep.id);
  res.status(201).json(rep);
});

staffRepresentativesRouter.patch('/staff/representatives/:id', ...writers, validate({ params: idParams, body: repBody.partial() }), async (req, res) => {
  const { id } = res.locals.params as z.infer<typeof idParams>;
  const rep = await updateRep(id, req.body as Partial<RepInput>);
  staffAudit(req, 'rep_updated', id, { fields: Object.keys(req.body as object).join(',') });
  res.json(rep);
});

staffRepresentativesRouter.delete('/staff/representatives/:id', ...writers, validate({ params: idParams }), async (req, res) => {
  const { id } = res.locals.params as z.infer<typeof idParams>;
  const rep = await deactivateRep(id);
  staffAudit(req, 'rep_deactivated', id);
  res.json(rep);
});

staffRepresentativesRouter.get('/staff/constituencies', ...readers, async (_req, res) => {
  res.json({ items: await listConstituencies() });
});

staffRepresentativesRouter.put('/staff/wards/:id/constituencies', ...writers, validate({ params: idParams, body: mappingBody }), async (req, res) => {
  const { id } = res.locals.params as z.infer<typeof idParams>;
  const out = await setWardConstituencies(id, (req.body as z.infer<typeof mappingBody>).items);
  staffAudit(req, 'ward_constituencies_updated', id, { count: out.items.length });
  res.json(out);
});
