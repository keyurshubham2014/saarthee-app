/**
 * Public AMC services directory (V2 TASK-12 §5.3, REQ-F-057, REQ-F-061): GET /services, /services/tips,
 * /services/{slug}. Saarthee is an independent guide; every response points at AMC's own pages.
 */
import { Router } from 'express';
import { z } from 'zod';
import { rateLimit } from '../../middleware/rateLimit';
import { validate } from '../../middleware/validate';
import { SERVICE_CATEGORIES } from '../../../prisma/seed-data/services';
import { getService, listServices, listTips } from './services.service';

export const servicesRouter = Router();

const limiter = rateLimit({ windowMs: 60_000, max: 120 });

const listQuery = z.object({
  category: z.enum(SERVICE_CATEGORIES).optional(),
  q: z.string().max(50).optional(),
});

const tipsQuery = z.object({
  ward: z.uuid().optional(),
  date: z.iso.date().optional(),
});

const slugParams = z.object({ slug: z.string().regex(/^[a-z0-9-]{3,60}$/) });
const detailQuery = z.object({ ward: z.uuid().optional() });

servicesRouter.get('/services', limiter, validate({ query: listQuery }), async (_req, res) => {
  res.json(await listServices(res.locals.query as z.infer<typeof listQuery>));
});

// Registered before /services/:slug so "tips" is never read as a slug.
servicesRouter.get('/services/tips', limiter, validate({ query: tipsQuery }), async (_req, res) => {
  res.json(await listTips(res.locals.query as z.infer<typeof tipsQuery>));
});

servicesRouter.get('/services/:slug', limiter, validate({ params: slugParams, query: detailQuery }), async (_req, res) => {
  const { slug } = res.locals.params as z.infer<typeof slugParams>;
  const { ward } = res.locals.query as z.infer<typeof detailQuery>;
  res.json(await getService(slug, ward));
});
