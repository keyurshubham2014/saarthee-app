// T-02-05 (AC-6, AC-7) and T-02-06 (AC-8): /wards, /wards/{id}, /zones on the committed real data.
import { afterEach, beforeAll, describe, expect, it } from 'vitest';
import { prisma } from '../../src/lib/db';
import { resetRateLimitStores } from '../../src/middleware/rateLimit';
import { api } from '../helpers/app';
import { resetDb } from '../helpers/db';
import { importRealWards } from './helpers';

const ZONE_ORDER = ['central', 'north', 'south', 'east', 'west', 'north_west', 'south_west'];

beforeAll(async () => {
  await resetDb();
  await importRealWards();
}, 60_000);
afterEach(resetRateLimitStores);

describe('GET /wards and /zones', () => {
  it('lists 48 wards with gu/en names and zone, ordered by zone then number; payload < 15 KB', async () => {
    const res = await api().get('/api/v1/wards');
    expect(res.status).toBe(200);
    expect(res.headers['cache-control']).toBe('public, max-age=3600');
    expect(res.body.boundaryVersion).toBe('opencity-amc-wards-2025-11');
    const items = res.body.items as { number: number; nameEn: string; nameGu: string; zone: { code: string; id: string } }[];
    expect(items).toHaveLength(48);
    for (const w of items) {
      expect(Object.keys(w).sort()).toEqual(['id', 'nameEn', 'nameGu', 'number', 'zone']);
      expect(w.nameGu).toMatch(/[઀-૿]/);
      expect(Object.keys(w.zone).sort()).toEqual(['code', 'id', 'nameEn', 'nameGu']);
    }
    const order = items.map((w) => [ZONE_ORDER.indexOf(w.zone.code), w.number]);
    expect(order).toEqual([...order].sort((a, b) => a[0]! - b[0]! || a[1]! - b[1]!));
    expect(Buffer.byteLength(JSON.stringify(res.body))).toBeLessThan(15_000);
  });

  it('?zone=west returns only West-zone wards', async () => {
    const res = await api().get('/api/v1/wards?zone=west');
    expect(res.body.items).toHaveLength(9);
    expect(new Set(res.body.items.map((w: { zone: { code: string } }) => w.zone.code))).toEqual(new Set(['west']));
  });

  it.each(['પાલડી', 'paldi', 'PAL', '30', '૩૦', 'ward 30'])('?q=%s finds Paldi', async (q) => {
    const res = await api().get(`/api/v1/wards?q=${encodeURIComponent(q)}`);
    expect(res.status).toBe(200);
    expect(res.body.items.map((w: { nameEn: string }) => w.nameEn)).toEqual(['Paldi']);
  });

  it('?q=nava finds Nava Vadaj; no match → empty list; bad params → 400', async () => {
    const nava = await api().get('/api/v1/wards?q=nava');
    expect(nava.body.items.map((w: { number: number }) => w.number)).toContain(6);
    expect((await api().get('/api/v1/wards?q=zzz')).body.items).toEqual([]);
    const long = await api().get(`/api/v1/wards?q=${'x'.repeat(41)}`);
    expect(long.status).toBe(400);
    expect(long.body.error.details[0].field).toBe('q');
    expect((await api().get('/api/v1/wards?zone=WEST!')).status).toBe(400);
  });

  it('/zones returns 7 zones in fixed order whose wardCount totals 48', async () => {
    const res = await api().get('/api/v1/zones');
    expect(res.status).toBe(200);
    expect(res.body.items.map((z: { code: string }) => z.code)).toEqual(ZONE_ORDER);
    expect(res.body.items.reduce((s: number, z: { wardCount: number }) => s + z.wardCount, 0)).toBe(48);
    expect(res.body.items[0]).toMatchObject({ code: 'central', nameEn: 'Central', nameGu: 'મધ્ય ઝોન', wardCount: 6 });
  });
});

describe('GET /wards/{id}', () => {
  it('by id and by number return the same WardDetail with office, source, centroid and bbox', async () => {
    const paldi = await prisma.ward.findUniqueOrThrow({ where: { number: 30 } });
    const byId = await api().get(`/api/v1/wards/${paldi.id}`);
    const byNumber = await api().get('/api/v1/wards/30');
    expect(byId.status).toBe(200);
    expect(byNumber.body).toEqual(byId.body);
    const d = byId.body;
    expect(d).toMatchObject({ id: paldi.id, number: 30, nameEn: 'Paldi', nameGu: 'પાલડી', zone: { code: 'west' } });
    expect(d.office.addressEn).toContain('Paldi');
    expect(d.office.phone).toBeNull();
    expect(d.source).toEqual({ name: 'AMC ward list', url: 'https://amccrs.com/AMCPortal/Home/WardList', lastVerifiedAt: expect.any(String) });
    expect(d.boundaryVersion).toBe('opencity-amc-wards-2025-11');
    const [minLng, minLat, maxLng, maxLat] = d.bbox;
    expect(d.centroid.lat).toBeGreaterThan(minLat);
    expect(d.centroid.lat).toBeLessThan(maxLat);
    expect(d.centroid.lng).toBeGreaterThan(minLng);
    expect(d.centroid.lng).toBeLessThan(maxLng);
    expect(d.geometry).toBeUndefined();
  });

  it('?include=geometry adds a simplified MultiPolygon (< 60 KB); Gujarati-digit number works', async () => {
    const res = await api().get('/api/v1/wards/૩૦?include=geometry');
    expect(res.status).toBe(200);
    expect(res.body.number).toBe(30);
    expect(res.body.geometry.type).toBe('MultiPolygon');
    expect(res.body.geometry.coordinates[0][0].length).toBeGreaterThan(3);
    expect(Buffer.byteLength(JSON.stringify(res.body))).toBeLessThan(60_000);
  });

  it('unknown number → 404; unknown uuid → 404; malformed id → 400', async () => {
    const r999 = await api().get('/api/v1/wards/999');
    expect(r999.status).toBe(404);
    expect(r999.body.error.code).toBe('NOT_FOUND');
    expect((await api().get('/api/v1/wards/00000000-0000-4000-8000-000000000000')).status).toBe(404);
    expect((await api().get('/api/v1/wards/paldi')).status).toBe(400);
    expect((await api().get('/api/v1/wards/30?include=everything')).status).toBe(400);
  });
});

describe('caching and rate limits (T-02-06)', () => {
  it('a repeat with If-None-Match returns 304 with no body; the ETag changes when data changes', async () => {
    const first = await api().get('/api/v1/wards');
    const etag = first.headers.etag as string;
    expect(etag).toMatch(/^W\/"opencity-amc-wards-2025-11-\d+"$/);
    const again = await api().get('/api/v1/wards').set('If-None-Match', etag);
    expect(again.status).toBe(304);
    expect(again.text ?? '').toBe('');
    expect((await api().get('/api/v1/zones').set('If-None-Match', etag)).status).toBe(304);
    await prisma.zone.update({ where: { code: 'west' }, data: { nameEn: 'West' } }); // bumps updated_at
    expect((await api().get('/api/v1/wards').set('If-None-Match', etag)).status).toBe(200);
  });

  it('the 121st public geo request in a minute → 429 RATE_LIMITED with Retry-After (shared limiter)', async () => {
    const paths = ['/api/v1/wards', '/api/v1/zones', '/api/v1/wards/30', '/api/v1/geo/locate?lat=23.012&lng=72.56'];
    for (let i = 0; i < 120; i++) {
      const res = await api().get(paths[i % paths.length]!);
      expect(res.status, `call ${i + 1}`).not.toBe(429);
    }
    const res = await api().get('/api/v1/zones');
    expect(res.status).toBe(429);
    expect(res.body.error.code).toBe('RATE_LIMITED');
    expect(res.headers['retry-after']).toBe('60');
  }, 60_000);
});
