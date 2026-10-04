/**
 * `npm run perf:read` (V2 TASK-07 T-07-15, REQ-N-011): p50/p95 of feed, list, detail and map under
 * PERF_CONNECTIONS (default 50) concurrent clients for PERF_SECONDS (default 60) each, against a running
 * API at PERF_BASE_URL (default http://127.0.0.1:4000). Seed first with `npm run seed:perf`.
 * Dependency-free (global fetch) instead of autocannon. Exit 1 if any p95 ≥ 400 ms.
 */
const base = (process.env.PERF_BASE_URL ?? 'http://127.0.0.1:4000').replace(/\/$/, '');
const connections = Number(process.env.PERF_CONNECTIONS ?? 50);
const seconds = Number(process.env.PERF_SECONDS ?? 60);
const BBOX = process.env.PERF_BBOX ?? '72.548,22.99,72.575,23.02';

async function json(path: string): Promise<Record<string, unknown>> {
  const r = await fetch(`${base}${path}`);
  if (!r.ok) throw new Error(`${path} → ${r.status}`);
  return (await r.json()) as Record<string, unknown>;
}

async function run(name: string, next: () => string) {
  const times: number[] = [];
  let errors = 0;
  const end = Date.now() + seconds * 1000;
  await Promise.all(
    Array.from({ length: connections }, async () => {
      while (Date.now() < end) {
        const t = performance.now();
        // Per-IP rate limits (120/min): each request poses as a different client via X-Forwarded-For
        // (the server must run with TRUST_PROXY); otherwise 429s are counted as errors.
        const ip = `10.${(Math.random() * 255) | 0}.${(Math.random() * 255) | 0}.${(Math.random() * 255) | 0}`;
        const r = await fetch(`${base}${next()}`, { headers: { 'x-forwarded-for': ip } }).catch(() => null);
        if (!r || !r.ok) errors++;
        else await r.arrayBuffer();
        times.push(performance.now() - t);
      }
    }),
  );
  times.sort((a, b) => a - b);
  const pct = (p: number) => Math.round(times[Math.min(times.length - 1, Math.ceil(times.length * p) - 1)] ?? 0);
  return { name, requests: times.length, errors, p50: pct(0.5), p95: pct(0.95) };
}

async function main() {
  const list = await json('/api/v1/issues?limit=50');
  const items = (list.items as { id: string }[]) ?? [];
  if (items.length === 0) throw new Error('No issues: run `npm run seed:perf` first.');
  const ward = ((await json('/api/v1/wards')).items as { id: string }[] | undefined)?.[0]?.id;
  let n = 0;
  const results = [
    await run('feed', () => `/api/v1/feed?ward=${ward}`),
    await run('list', () => `/api/v1/issues?sort=${['newest', 'most_affected', 'overdue'][n++ % 3]}`),
    await run('detail', () => `/api/v1/issues/${items[n++ % items.length]!.id}`),
    await run('map', () => `/api/v1/map/issues?bbox=${BBOX}&zoom=${12 + (n++ % 5)}`),
  ];
  console.table(results);
  if (results.some((r) => r.p95 >= 400)) process.exit(1);
}

main().catch((e) => {
  console.error(e instanceof Error ? e.message : e);
  process.exit(1);
});
