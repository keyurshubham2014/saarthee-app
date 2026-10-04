// REQ-N-011 (AC-10) in CI: p95 < 400 ms for feed, list (each sort, paged), detail and map on the perf seed
// (5,000 issues, 20,000 events, 30,000 me-toos, 15,000 follows). In-process, sequential; the 50-connection
// autocannon run is `npm run perf:read` (T-07-15, recorded in the task file).
import { beforeAll, describe, expect, it } from 'vitest';
import { seedPerfIssues } from '../../prisma/seed/perf-issues';
import { prisma } from '../../src/lib/db';
import { clearFeedCache } from '../../src/modules/feed';
import { resetDb } from '../helpers/db';
import { resetRateLimitStores } from '../../src/middleware/rateLimit';
import { get, seedReference, user } from './helpers';

const RUNS = 40;
const DENSE: [number, number, number, number] = [72.5, 23.0, 72.51, 23.01];

function p95(ms: number[]): number {
  const s = [...ms].sort((a, b) => a - b);
  return s[Math.min(s.length - 1, Math.ceil(s.length * 0.95) - 1)]!;
}

async function measure(paths: () => string, auth?: Record<string, string>, before?: () => void): Promise<number> {
  // 40 requests per endpoint stay under 120/IP/min once counters are cleared.
  await resetRateLimitStores();
  const times: number[] = [];
  for (let n = 0; n < RUNS; n++) {
    before?.();
    const p = paths();
    const t = performance.now();
    const res = await get(p, auth);
    times.push(performance.now() - t);
    expect(res.status, p).toBe(200);
  }
  return p95(times);
}

let wardId = '';
let issueIds: string[] = [];
let cursor = '';

beforeAll(async () => {
  await resetDb();
  await seedReference();
  await seedPerfIssues(prisma, { denseBbox: DENSE });
  wardId = (await prisma.ward.findFirstOrThrow({ where: { number: 1 } })).id;
  issueIds = (await prisma.issue.findMany({ where: { visibility: 'public', status: { not: 'rejected' } }, take: RUNS, select: { id: true } })).map((i) => i.id);
  cursor = (await get('/api/v1/issues?limit=50')).body.nextCursor;
}, 180_000);

describe('read latency on the perf seed (p95 < 400 ms)', () => {
  it('seed volume', async () => {
    expect(await prisma.issue.count()).toBe(5000);
    expect(await prisma.issueEvent.count()).toBe(20000);
    expect(await prisma.meToo.count()).toBe(30000);
    expect(await prisma.follow.count()).toBe(15000);
  });

  it('feed (uncached), lists, detail, map clusters and points', async () => {
    const me = await user();
    const results: Record<string, number> = {
      feed: await measure(() => `/api/v1/feed?ward=${wardId}`, undefined, clearFeedCache),
      listNewest: await measure(() => '/api/v1/issues?limit=20'),
      listPage2: await measure(() => `/api/v1/issues?limit=50&cursor=${cursor}`),
      listWardAffected: await measure(() => `/api/v1/issues?ward=${wardId}&sort=most_affected`),
      listOverdue: await measure(() => '/api/v1/issues?sort=overdue'),
      listBbox: await measure(() => `/api/v1/issues?bbox=${DENSE.join(',')}`),
      listMine: await measure(() => '/api/v1/issues?mine=true', me.auth),
      detail: await measure(((n) => () => `/api/v1/issues/${issueIds[n++ % issueIds.length]}`)(0), me.auth),
      mapClusters: await measure(() => `/api/v1/map/issues?bbox=${DENSE.join(',')}&zoom=12`),
      mapPoints: await measure(() => `/api/v1/map/issues?bbox=72.5,23.0,72.502,23.002&zoom=16`),
    };
    process.stdout.write(`TASK-07 p95 ms ${JSON.stringify(Object.fromEntries(Object.entries(results).map(([k, v]) => [k, Math.round(v)])))}\n`);
    for (const [k, v] of Object.entries(results)) expect(v, k).toBeLessThan(400);
  }, 180_000);
});
