/** Categories admin on v2 `categories` (TASK-10 §5.3). Slug immutable, no DELETE; GET also for moderators. */
import { Router } from 'express';
import { Prisma } from '@prisma/client';
import { z } from 'zod';
import { auditStaff } from '../../lib/audit';
import { prisma } from '../../lib/db';
import { AppError } from '../../lib/errors';
import { validate } from '../../middleware/validate';
import { admins, idOf, idParams, moderators } from './common';

export const categoriesRouter = Router();

/** DS §2 category colours (one token per category palette entry). */
export const CATEGORY_COLOUR_TOKENS = [
  'roads', 'water', 'drainage', 'garbage', 'streetlight', 'trees', 'animals', 'health', 'toilets', 'encroachment', 'traffic',
  'property', 'building', 'other',
].map((s) => `category.${s}`);

/** Material Symbols Rounded allow-list (DS §2 category icons plus a few civic extras). */
export const CATEGORY_ICONS = [
  'road', 'water_drop', 'water_damage', 'delete', 'lightbulb', 'park', 'pets', 'pest_control', 'wc', 'do_not_step', 'traffic',
  'receipt_long', 'apartment', 'more_horiz', 'construction', 'cleaning_services', 'local_hospital', 'directions_bus', 'school',
];

const fields = {
  nameEn: z.string().trim().min(2).max(60),
  nameGu: z.string().trim().min(2).max(60),
  icon: z.enum(CATEGORY_ICONS as [string, ...string[]]),
  colourToken: z.enum(CATEGORY_COLOUR_TOKENS as [string, ...string[]]),
  slaDays: z.number().int().min(1).max(90),
  sensitive: z.boolean(),
  isActive: z.boolean(),
  sortOrder: z.number().int().min(0).max(999),
};
const createBody = z.strictObject({ slug: z.string().regex(/^[a-z][a-z0-9_]{1,31}$/), ...fields });
const patchBody = z
  .strictObject(Object.fromEntries(Object.entries(fields).map(([k, v]) => [k, v.optional()])) as { [K in keyof typeof fields]: z.ZodOptional<(typeof fields)[K]> })
  .refine((v) => Object.keys(v).length > 0, { message: 'Nothing to change.' });

const dto = (c: Prisma.CategoryGetPayload<object>) => ({
  id: c.id, slug: c.slug, nameEn: c.nameEn, nameGu: c.nameGu, icon: c.icon, colourToken: c.colourToken, slaDays: c.slaDays,
  sensitive: c.sensitive, isActive: c.isActive, sortOrder: c.sortOrder, updatedAt: c.updatedAt,
});

categoriesRouter.get('/staff/categories', ...moderators, async (_req, res) => {
  const rows = await prisma.category.findMany({ orderBy: [{ sortOrder: 'asc' }, { slug: 'asc' }] });
  res.json({ items: rows.map(dto), colourTokens: CATEGORY_COLOUR_TOKENS, icons: CATEGORY_ICONS });
});

categoriesRouter.post('/staff/categories', ...admins, validate({ body: createBody }), async (req, res) => {
  try {
    const row = await prisma.category.create({ data: req.body as z.infer<typeof createBody> });
    auditStaff(req, 'category_created', { targetType: 'category', targetId: row.id });
    res.status(201).json(dto(row));
  } catch (err) {
    if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') throw new AppError('SLUG_TAKEN');
    throw err;
  }
});

categoriesRouter.patch('/staff/categories/:id', ...admins, validate({ params: idParams, body: patchBody }), async (req, res) => {
  const id = idOf(res);
  if (!(await prisma.category.count({ where: { id } }))) throw new AppError('NOT_FOUND');
  const row = await prisma.category.update({ where: { id }, data: req.body as z.infer<typeof patchBody> });
  auditStaff(req, 'category_updated', { targetType: 'category', targetId: id, extra: { fields: Object.keys(req.body as object).length } });
  res.json(dto(row));
});
