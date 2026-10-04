/**
 * GET /feed?ward (V2 TASK-07 §5.3, REQ-F-028): the Home sections for one ward, composed from registered
 * providers in parallel (each degrades on its own), cached per ward + language for FEED_CACHE_SECONDS,
 * with an ETag. Anonymous content only; viewer-specific state is fetched separately by the app.
 */
import { createHash } from 'node:crypto';
import { Router } from 'express';
import { config } from '../../config';
import { now as clockNow } from '../../lib/clock';
import { prisma } from '../../lib/db';
import { AppError } from '../../lib/errors';
import { rateLimit } from '../../middleware/rateLimit';
import { optionalUser } from '../../middleware/requireUser';
import { validate } from '../../middleware/validate';
import { feedQuery } from '../issues/list.schemas';
import { FEED_SECTIONS, runSection, type FeedContext } from './registry';
import './providers';

interface Cached {
  body: unknown;
  etag: string;
  expires: number;
}
const cache = new Map<string, Cached>();

/** Tests: forget cached feeds. */
export function clearFeedCache(): void {
  cache.clear();
}

export async function composeFeed(wardId: string, lang: 'en' | 'gu') {
  const ward = await prisma.ward.findUnique({
    where: { id: wardId },
    select: { id: true, number: true, nameEn: true, nameGu: true, zone: { select: { code: true, nameEn: true, nameGu: true } } },
  });
  if (!ward) throw new AppError('NOT_FOUND');
  const ctx: FeedContext = { wardId, lang, now: clockNow() };
  const results = await Promise.all(FEED_SECTIONS.map((s) => runSection(s, ctx)));
  return {
    ward,
    sections: Object.fromEntries(FEED_SECTIONS.map((s, i) => [s, results[i]])),
    generatedAt: ctx.now,
  };
}

export const feedRouter = Router();
const limiter = rateLimit({ windowMs: 60_000, max: 120 });

feedRouter.get('/feed', limiter, optionalUser, validate({ query: feedQuery }), async (req, res) => {
  const q = res.locals.query as { ward?: string; lang: 'en' | 'gu' };
  const wardId = q.ward ?? req.user?.homeWardId ?? undefined;
  if (!wardId) throw new AppError('WARD_REQUIRED');
  const key = `${wardId}:${q.lang}`;
  let hit = cache.get(key);
  if (!hit || hit.expires <= Date.now()) {
    const body = await composeFeed(wardId, q.lang);
    const etag = `"${createHash('sha1').update(JSON.stringify(body.sections)).digest('base64url')}"`;
    hit = { body, etag, expires: Date.now() + config.FEED_CACHE_SECONDS * 1000 };
    if (config.FEED_CACHE_SECONDS > 0) cache.set(key, hit);
  }
  res.setHeader('ETag', hit.etag);
  res.setHeader('Cache-Control', `public, max-age=${config.FEED_CACHE_SECONDS}`);
  if (req.header('if-none-match') === hit.etag) {
    res.status(304).end();
    return;
  }
  res.json(hit.body);
});
