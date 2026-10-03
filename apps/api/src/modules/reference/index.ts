import { Router } from 'express';
import { z } from 'zod';
import { auditLog } from '../../lib/audit';
import { MSG } from '../../lib/validation';
import { validate } from '../../middleware/validate';
import {
  createCategory,
  createInviteCode,
  listCategories,
  listInviteCodes,
  updateCategory,
  updateInviteCode,
} from './reference.service';

/** Invite codes and categories (03 §2.2 admin reference data). Mounted on the /admin router. */
export const referenceRouter = Router();

const idParams = z.object({ id: z.uuid() });
const optionalText = (max: number) =>
  z
    .string()
    .trim()
    .max(max)
    .transform((v) => (v === '' ? null : v));

const createInviteBody = z.object({
  code: z
    .string()
    .trim()
    .regex(/^[A-Za-z0-9]{6,20}$/, MSG.inviteCode)
    .optional(),
  sourceTag: z.enum(['rwa', 'activist', 'social', 'network']),
  groupLabel: z.string().trim().min(1).max(120),
  wardHint: z.string().trim().min(1).max(50).optional(),
});

// The source tag of an existing code cannot be changed (03 §2.2): it is not in this schema.
const updateInviteBody = z
  .object({
    groupLabel: z.string().trim().min(1).max(120).optional(),
    wardHint: optionalText(50).nullable().optional(),
    isActive: z.boolean().optional(),
  })
  .strict();

referenceRouter.get('/invite-codes', async (_req, res) => {
  res.json({ items: await listInviteCodes() });
});

referenceRouter.post('/invite-codes', validate({ body: createInviteBody }), async (req, res) => {
  const created = await createInviteCode(req.body as z.infer<typeof createInviteBody>, req.admin!.id);
  auditLog(req, 'invite_code_created', created.id);
  res.status(201).json(created);
});

referenceRouter.patch('/invite-codes/:id', validate({ params: idParams, body: updateInviteBody }), async (req, res) => {
  const { id } = res.locals.params as z.infer<typeof idParams>;
  const updated = await updateInviteCode(id, req.body as z.infer<typeof updateInviteBody>);
  auditLog(req, 'invite_code_updated', id);
  res.json(updated);
});

const createCategoryBody = z.object({
  name: z.string().trim().min(1).max(100),
  ccrsLabel: z.string().trim().min(1).max(150).optional(),
  sortOrder: z.number().int().min(0),
});

const updateCategoryBody = z
  .object({
    name: z.string().trim().min(1).max(100).optional(),
    ccrsLabel: optionalText(150).nullable().optional(),
    sortOrder: z.number().int().min(0).optional(),
    isActive: z.boolean().optional(),
  })
  .strict();

referenceRouter.get('/categories', async (_req, res) => {
  res.json({ items: await listCategories() });
});

referenceRouter.post('/categories', validate({ body: createCategoryBody }), async (req, res) => {
  const created = await createCategory(req.body as z.infer<typeof createCategoryBody>);
  auditLog(req, 'category_created', created.id);
  res.status(201).json(created);
});

referenceRouter.patch('/categories/:id', validate({ params: idParams, body: updateCategoryBody }), async (req, res) => {
  const { id } = res.locals.params as z.infer<typeof idParams>;
  const updated = await updateCategory(id, req.body as z.infer<typeof updateCategoryBody>);
  auditLog(req, 'category_updated', id);
  res.json(updated);
});
