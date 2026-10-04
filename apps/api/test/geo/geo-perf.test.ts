// TASK-02 §7.2: /geo/locate p95 < 50 ms with 48 wards, GIST index used. Opt-in (timing-sensitive):
//   GEO_PERF=1 npx vitest run test/geo/geo-perf.test.ts
import { beforeAll, describe, expect, it } from 'vitest';
import { prisma } from '../../src/lib/db';
import { resetRateLimitStores } from '../../src/middleware/rateLimit';
import { api } from '../helpers/app';
import { resetDb } from '../helpers/db';
import { importRealWards } from './helpers';

describe.runIf(process.env.GEO_PERF === '1')('geo performance', () => {
  beforeAll(async () => {
    await resetDb();
    await importRealWards();
    await prisma.$executeRaw`ANALYZE wards`;
  }, 60_000);

  it('GET /geo/locate p95 < 50 ms over 200 points across the city (in-process)', async () => {
    const times: number[] = [];
    for (let i = 0; i < 200; i++) {
      if (i % 100 === 0) await resetRateLimitStores();
      // Deterministic spread over the AMC bounding box (incl. points just outside).
      const lat = 22.92 + ((i * 37) % 200) / 200 * 0.22;
      const lng = 72.47 + ((i * 53) % 200) / 200 * 0.24;
      const t = process.hrtime.bigint();
      const res = await api().get(`/api/v1/geo/locate?lat=${lat.toFixed(6)}&lng=${lng.toFixed(6)}`);
      times.push(Number(process.hrtime.bigint() - t) / 1e6);
      expect([200, 422]).toContain(res.status);
    }
    times.sort((a, b) => a - b);
    const p95 = times[Math.floor(times.length * 0.95)]!;
    console.error(`geo:locate perf p50=${times[100]!.toFixed(1)}ms p95=${p95.toFixed(1)}ms`);
    expect(p95).toBeLessThan(50);
  }, 60_000);

  it('the point-in-polygon query uses the GIST index', async () => {
    await prisma.$executeRawUnsafe('SET enable_seqscan = off'); // 48 rows: force the planner to show the index path
    const plan = await prisma.$queryRaw<{ 'QUERY PLAN': string }[]>`
      EXPLAIN SELECT id FROM wards WHERE ST_Covers(geom, ST_SetSRID(ST_MakePoint(72.56, 23.012), 4326)) ORDER BY number LIMIT 1`;
    await prisma.$executeRawUnsafe('RESET enable_seqscan');
    expect(plan.map((r) => r['QUERY PLAN']).join('\n')).toMatch(/idx_wards_geom/);
  });
});
