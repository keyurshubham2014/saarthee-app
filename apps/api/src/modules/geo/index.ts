/**
 * Public geo endpoints (V2 TASK-02 §5.3): GET /geo/locate, /wards, /wards/{id}, /zones.
 * One shared limiter, 120 per IP per minute. Lists/detail: Cache-Control public 1 h + weak ETag (304 on match);
 * locate: no-store. Coordinates are never logged; only the match kind and ward number.
 */
import { Router, type Request, type Response } from 'express';
import type { z } from 'zod';
import { logger } from '../../lib/logger';
import { rateLimit } from '../../middleware/rateLimit';
import { validate } from '../../middleware/validate';
import { locateQuery, wardDetailQuery, wardParams, wardsQuery } from './geo.schemas';
import { geoEtag, getWard, listWards, listZones, locate } from './geo.service';

export { resolveWard } from './geo.service';

export const geoRouter = Router();

const geoLimiter = rateLimit({ windowMs: 60_000, max: 120 });

/** Sets cache headers; returns true (after sending 304) when the client's ETag is current. */
async function notModified(req: Request, res: Response): Promise<boolean> {
  const etag = await geoEtag();
  res.setHeader('Cache-Control', 'public, max-age=3600');
  res.setHeader('ETag', etag);
  const inm = req.get('If-None-Match');
  if (inm && inm.split(',').some((t) => t.trim() === etag || t.trim() === '*')) {
    res.status(304).end();
    return true;
  }
  return false;
}

geoRouter.get('/geo/locate', geoLimiter, validate({ query: locateQuery }), async (req, res) => {
  const { lat, lng } = res.locals.query as z.infer<typeof locateQuery>;
  res.setHeader('Cache-Control', 'no-store');
  const result = await locate(lat, lng);
  logger.info({ requestId: req.id, match: result.match, wardNumber: result.ward.number }, 'geo locate');
  res.json(result);
});

geoRouter.get('/wards', geoLimiter, validate({ query: wardsQuery }), async (req, res) => {
  if (await notModified(req, res)) return;
  const { q, zone } = res.locals.query as z.infer<typeof wardsQuery>;
  res.json(await listWards(q, zone));
});

geoRouter.get(
  '/wards/:id',
  geoLimiter,
  validate({ params: wardParams, query: wardDetailQuery }),
  async (req, res) => {
    if (await notModified(req, res)) return;
    const { id } = res.locals.params as z.infer<typeof wardParams>;
    const { include } = res.locals.query as z.infer<typeof wardDetailQuery>;
    res.json(await getWard(id, include === 'geometry'));
  },
);

geoRouter.get('/zones', geoLimiter, async (req, res) => {
  if (await notModified(req, res)) return;
  res.json(await listZones());
});
