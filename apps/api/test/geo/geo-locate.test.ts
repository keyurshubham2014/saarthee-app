// T-02-03 (AC-3, AC-4) and T-02-04 (AC-5): GET /api/v1/geo/locate.
import { afterEach, beforeAll, describe, expect, it, vi } from 'vitest';
import { PILOT_POINTS } from '../../prisma/seed/modules/050-issues';
import { logger } from '../../src/lib/logger';
import { resetRateLimitStores } from '../../src/middleware/rateLimit';
import { resolveWard } from '../../src/modules/geo';
import { api } from '../helpers/app';
import { resetDb } from '../helpers/db';
import { importFixtureWards, importRealWards, wardPoint } from './helpers';

const locate = (q: string) => api().get(`/api/v1/geo/locate?${q}`);

afterEach(async () => {
  await resetRateLimitStores();
  vi.restoreAllMocks();
});

describe('locate on the 3-ward fixture', () => {
  beforeAll(async () => {
    await resetDb();
    await importFixtureWards();
  });

  it('each ward centroid → that ward, inside, confirm false, distance 0, no-store', async () => {
    for (const n of [1, 2, 3]) {
      const { lat, lng } = await wardPoint(n);
      const res = await locate(`lat=${lat}&lng=${lng}`);
      expect(res.status).toBe(200);
      expect(res.headers['cache-control']).toBe('no-store');
      expect(res.body).toMatchObject({ ward: { number: n }, match: 'inside', confirm: false, distanceM: 0, boundaryVersion: 'fixture-v1' });
      expect(res.body.zone).toEqual(res.body.ward.zone);
      expect(res.body.zone.code).toBe(n === 3 ? 'east' : 'west');
    }
  });

  it('a point on the shared boundary of wards 1 and 2 → the lower number (1)', async () => {
    const res = await locate('lat=23.005&lng=72.51');
    expect(res.body).toMatchObject({ ward: { number: 1 }, match: 'inside' });
  });

  it('500 m outside the edge ward → nearest, confirm true, distance ≈ 500 m', async () => {
    // 0.004876° of longitude ≈ 500 m at 23.005° N.
    const res = await locate('lat=23.005&lng=72.495124');
    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({ ward: { number: 1 }, match: 'nearest', confirm: true });
    expect(Math.abs(res.body.distanceM - 500)).toBeLessThanOrEqual(50);
  });

  it('a far point (Gandhinagar) → 422 OUTSIDE_SERVICE_AREA; resolveWard returns null', async () => {
    const res = await locate('lat=23.2156&lng=72.6369');
    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe('OUTSIDE_SERVICE_AREA');
    expect(await resolveWard(23.2156, 72.6369)).toBeNull();
  });
});

describe('locate input validation (T-02-04)', () => {
  it.each([
    ['lat=abc&lng=72.5', 'lat'],
    ['lat=23.0', 'lng'],
    ['lat=95&lng=72.5', 'lat'],
    ['lat=23&lng=181', 'lng'],
    ['lat=&lng=72.5', 'lat'],
  ])('%s → 400 VALIDATION_FAILED naming %s', async (q, field) => {
    const res = await locate(q);
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_FAILED');
    expect(res.body.error.details.map((d: { field: string }) => d.field)).toContain(field);
  });

  it('never logs coordinates at info level (only match and ward number)', async () => {
    await resetDb();
    await importFixtureWards();
    const info = vi.spyOn(logger, 'info');
    await locate('lat=23.004321&lng=72.504321');
    await locate('lat=abc&lng=72.987654');
    const logged = JSON.stringify(info.mock.calls);
    expect(logged).toContain('"match":"inside"');
    expect(logged).toContain('"wardNumber":1');
    for (const s of ['23.004321', '72.504321', '72.987654']) expect(logged).not.toContain(s);
  });
});

describe('locate on the committed real wards (AC-3)', () => {
  beforeAll(async () => {
    await resetDb();
    await importRealWards();
  }, 60_000);

  it('all 48 ward centroids resolve to their own ward, inside', async () => {
    for (let n = 1; n <= 48; n++) {
      const { lat, lng } = await wardPoint(n);
      const res = await locate(`lat=${lat}&lng=${lng}`);
      expect(res.status, `ward ${n}`).toBe(200);
      expect(res.body, `ward ${n}`).toMatchObject({ ward: { number: n }, match: 'inside', confirm: false, distanceM: 0 });
    }
  }, 60_000);

  it('M-02-02 known places (the 5 pilot wards, Spec D5) resolve to the expected ward', async () => {
    const expected = { paldi: [30, 'Paldi'], navrangpura: [18, 'Navrangpura'], vasna: [31, 'Vasna'], naranpura: [9, 'Naranpura'], navaVadaj: [6, 'Nava Vadaj'] } as const;
    for (const [key, { lat, lng }] of Object.entries(PILOT_POINTS)) {
      const res = await locate(`lat=${lat}&lng=${lng}`);
      const [number, nameEn] = expected[key as keyof typeof expected];
      expect(res.body, key).toMatchObject({ ward: { number, nameEn }, zone: { code: 'west' }, match: 'inside' });
    }
  });

  it('Paldi cross-roads → ward 30 Paldi (west); Gandhinagar → 422', async () => {
    const paldi = await locate('lat=23.012&lng=72.56');
    expect(paldi.body).toMatchObject({ ward: { number: 30, nameEn: 'Paldi', nameGu: 'પાલડી' }, zone: { code: 'west' } });
    expect((await locate('lat=23.2156&lng=72.6369')).status).toBe(422);
  });
});
