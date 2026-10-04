// T-07-01..03 feed, T-07-07 map clustering, T-07-11 share page.
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { prisma } from '../../src/lib/db';
import { clearFeedCache } from '../../src/modules/feed';
import { FEED_SECTIONS, swapFeedProvider, type FeedProvider, type FeedSection } from '../../src/modules/feed/registry';
import { composer, publishFlow, staffUser } from '../alerts/helpers';
import { resetDb } from '../helpers/db';
import { api, categoryId, DAY, get, photoIssue, seedReference, user, ward } from './helpers';

const saved = new Map<FeedSection, FeedProvider | undefined>();
function swap(section: FeedSection, p: FeedProvider | undefined) {
  if (!saved.has(section)) saved.set(section, swapFeedProvider(section, p));
  else swapFeedProvider(section, p);
}

beforeEach(async () => {
  await resetDb();
  await seedReference();
  clearFeedCache();
});
afterEach(() => {
  for (const [s, p] of saved) swapFeedProvider(s, p);
  saved.clear();
});

describe('GET /feed', () => {
  it('T-07-01 no optional providers → degraded sections and 10 nearby issues, most affected first', async () => {
    for (const s of FEED_SECTIONS) if (s !== 'nearbyIssues') swap(s, undefined);
    const r = await user();
    const w = await ward(1);
    for (let n = 0; n < 12; n++) await photoIssue(r.user.id, { meTooCount: n });
    await photoIssue(r.user.id, { status: 'verified', meTooCount: 99 });
    const res = await get(`/api/v1/feed?ward=${w.id}`);
    expect(res.status).toBe(200);
    expect(res.body.ward).toMatchObject({ id: w.id, number: 1, nameEn: w.nameEn });
    expect(res.body.sections.nearbyIssues.degraded).toBe(false);
    expect(res.body.sections.nearbyIssues.items).toHaveLength(10);
    expect(res.body.sections.nearbyIssues.items[0].meTooCount).toBe(11);
    for (const s of ['alerts', 'drives', 'serviceShortcuts', 'tips']) expect(res.body.sections[s]).toEqual({ items: [], degraded: true });
  });

  it('T-07-02 throwing and slow (500 ms) providers → 200 within budget, degraded', async () => {
    swap('alerts', async () => {
      throw new Error('alerts down');
    });
    swap('drives', () => new Promise((resolve) => setTimeout(() => resolve([{ id: 'late' }]), 500)));
    const w = await ward(1);
    const t = Date.now();
    const res = await get(`/api/v1/feed?ward=${w.id}`);
    expect(Date.now() - t).toBeLessThan(400);
    expect(res.status).toBe(200);
    expect(res.body.sections.alerts).toEqual({ items: [], degraded: true });
    expect(res.body.sections.drives).toEqual({ items: [], degraded: true });
    expect(res.body.sections.nearbyIssues.degraded).toBe(false);
  });

  it('T-07-03 ETag → 304, Cache-Control, WARD_REQUIRED, unknown ward 404, home ward when signed in', async () => {
    const w = await ward(1);
    const first = await get(`/api/v1/feed?ward=${w.id}`);
    expect(first.headers['cache-control']).toBe('public, max-age=30');
    const etag = first.headers.etag as string;
    expect(etag).toBeTruthy();
    expect((await api().get(`/api/v1/feed?ward=${w.id}`).set('If-None-Match', etag)).status).toBe(304);
    const none = await get('/api/v1/feed');
    expect(none.status).toBe(400);
    expect(none.body.error.code).toBe('WARD_REQUIRED');
    expect((await get('/api/v1/feed?ward=00000000-0000-4000-8000-000000000000')).status).toBe(404);
    const me = await user('citizen', { homeWardId: w.id });
    expect((await get('/api/v1/feed', me.auth)).body.ward.id).toBe(w.id);
  });

  it('shows the active alerts of the ward (TASK-08 provider)', async () => {
    const w = await ward(1);
    const mod = await staffUser('moderator');
    await publishFlow(composer({ scope: 'wards', wardIds: [w.id] }), [mod.auth], mod.auth);
    const res = await get(`/api/v1/feed?ward=${w.id}`);
    expect(res.body.sections.alerts.degraded).toBe(false);
    expect(res.body.sections.alerts.items).toHaveLength(1);
    expect(res.body.sections.alerts.items[0].titleEn ?? res.body.sections.alerts.items[0].title).toBeTruthy();
  });
});

describe('GET /map/issues', () => {
  const BBOX = '72.49,22.99,72.52,23.02';
  async function spread(n: number, reporterId: string, over: Record<string, unknown> = {}) {
    const w = await ward(1);
    const cat = await categoryId('roads');
    await prisma.issue.createMany({
      data: Array.from({ length: n }, (_, k) => ({
        clientSubmissionId: crypto.randomUUID(), reporterId, categoryId: cat, title: 'Pothole', wardId: w.id, zoneId: w.zoneId,
        lat: 23.0 + (k % 40) * 0.00025, lng: 72.5 + Math.floor(k / 40) * 0.0002, slaDueAt: new Date(Date.now() + DAY), ...over,
      })),
    });
  }

  it('clusters below zoom 15 with counts summing to the total; points at 16; cap → clusters; filters', async () => {
    const r = await user();
    await spread(600, r.user.id);
    await photoIssue(r.user.id, { category: 'garbage', slaDueAt: new Date(Date.now() - DAY) });
    const z12 = await get(`/api/v1/map/issues?bbox=${BBOX}&zoom=12`);
    expect(z12.status).toBe(200);
    expect(z12.body.mode).toBe('clusters');
    expect(z12.body.items.reduce((s: number, c: { count: number }) => s + c.count, 0)).toBe(601);
    expect(z12.body.items.some((c: { hasOverdue: boolean }) => c.hasOverdue)).toBe(true);
    // 601 points > MAP_POINTS_MAX (500) → clusters even at zoom 16.
    const capped = await get(`/api/v1/map/issues?bbox=${BBOX}&zoom=16`);
    expect(capped.body).toMatchObject({ mode: 'clusters', truncated: true });
    const pts = await get(`/api/v1/map/issues?bbox=${BBOX}&zoom=16&category=garbage`);
    expect(pts.body.mode).toBe('points');
    expect(pts.body.items).toHaveLength(1);
    expect(Object.keys(pts.body.items[0]).sort()).toEqual(['categorySlug', 'id', 'isOverdue', 'lat', 'lng', 'status']);
    expect(pts.body.items[0].isOverdue).toBe(true);
    expect((await get(`/api/v1/map/issues?bbox=${BBOX}&zoom=16&status=overdue`)).body.items).toHaveLength(1);
    const other = await user();
    expect((await get(`/api/v1/map/issues?bbox=${BBOX}&zoom=16&mine=true`, other.auth)).body.items).toHaveLength(0);
    expect((await get(`/api/v1/map/issues?bbox=${BBOX}&zoom=16&mine=true`)).status).toBe(401);
  });

  it('400 for bbox span > 0.5° and invalid zoom', async () => {
    expect((await get('/api/v1/map/issues?bbox=72,22.9,72.6,23&zoom=12')).status).toBe(400);
    expect((await get(`/api/v1/map/issues?bbox=${BBOX}&zoom=25`)).status).toBe(400);
    expect((await get(`/api/v1/map/issues?zoom=12`)).status).toBe(400);
  });
});

describe('GET /i/{id}', () => {
  it('OG tags, escaped text, CSP, noindex, no PII; 404 for hidden', async () => {
    const r = await user('citizen', { displayName: 'Secret Name' });
    const { issue, photoId } = await photoIssue(r.user.id, { description: '<script>alert(1)</script> & "pothole"' });
    const res = await api().get(`/i/${issue.id}`);
    expect(res.status).toBe(200);
    expect(res.headers['content-type']).toContain('text/html');
    expect(res.headers['content-security-policy']).toBe("default-src 'none'; img-src 'self'; style-src 'unsafe-inline'");
    expect(res.text).toContain('<meta name="robots" content="noindex">');
    expect(res.text).toContain('og:title');
    expect(res.text).toContain(`og:image" content="https://saarthee.in/api/v1/media/photos/${photoId}`);
    expect(res.text).toContain('&lt;script&gt;alert(1)&lt;/script&gt; &amp; &quot;pothole&quot;');
    expect(res.text).not.toContain('<script>');
    expect(res.text).toContain('Not run by or linked to AMC');
    expect(res.text).not.toContain('Secret Name');
    expect(res.text).not.toContain(r.user.id);
    expect(res.text).not.toContain(r.user.phoneE164!);
    const hidden = await photoIssue(r.user.id, { visibility: 'hidden' });
    expect((await api().get(`/i/${hidden.issue.id}`)).status).toBe(404);
    expect((await api().get('/i/not-a-uuid')).status).toBe(404);
  });
});
