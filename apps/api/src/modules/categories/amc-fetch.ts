/**
 * `npm run amc:problems:fetch` logic (V2 TASK-05 §5.3, REQ-F-013). Polite by construction: refuses (exit 2)
 * when the last fetch is younger than AMC_PROBLEMS_MIN_INTERVAL_HOURS; one GET with a 20 s timeout; one
 * retry after 60 s on a network error only; never scheduled. `--from-snapshot` never touches the network.
 */
import fs from 'node:fs';
import type { PrismaClient } from '@prisma/client';
import { loadSnapshot, SNAPSHOT_PATH, syncProblemTypes, validateRows, type CcrsRow, type Snapshot, type SyncResult } from './amc';

export interface FetchDeps {
  prisma: PrismaClient;
  url: string;
  minIntervalHours: number;
  contactEmail: string;
  fromSnapshot: boolean;
  fetchImpl?: typeof fetch;
  sleep?: (ms: number) => Promise<void>;
  now?: () => Date;
  snapshotPath?: string;
  log?: (line: string) => void;
}

const FETCH_TIMEOUT_MS = 20_000;
const RETRY_AFTER_MS = 60_000;

async function getOnce(deps: FetchDeps): Promise<unknown> {
  const f = deps.fetchImpl ?? fetch;
  const res = await f(deps.url, {
    headers: { 'User-Agent': `Saarthee/2 (+${deps.contactEmail})`, Accept: 'application/json' },
    signal: AbortSignal.timeout(FETCH_TIMEOUT_MS),
  });
  if (!res.ok) throw Object.assign(new Error(`HTTP ${res.status}`), { http: true });
  return res.json();
}

function report(log: (l: string) => void, r: SyncResult) {
  log(`AMC problem types: ${r.total} rows; new ${r.created}, changed ${r.changed}, deactivated ${r.deactivated}, unmapped ${r.unmapped.length}.`);
  for (const u of r.unmapped) log(`  unmapped → other: ${u}`);
}

/** Returns the process exit code: 0 ok, 1 failed, 2 refused (interval guard). */
export async function runAmcFetch(deps: FetchDeps): Promise<number> {
  const log = deps.log ?? ((l: string) => void process.stdout.write(`${l}\n`));
  const now = deps.now ?? (() => new Date());
  const file = deps.snapshotPath ?? SNAPSHOT_PATH;

  if (deps.fromSnapshot) {
    const snap = loadSnapshot(file);
    const r = await deps.prisma.$transaction((tx) => syncProblemTypes(tx, validateRows(snap.rows), new Date(snap.fetchedAt)), { timeout: 60_000 });
    report(log, r);
    return 0;
  }

  const last = await deps.prisma.amcProblemType.aggregate({ _max: { fetchedAt: true } });
  const lastAt = last._max.fetchedAt;
  const nextAt = lastAt ? new Date(lastAt.getTime() + deps.minIntervalHours * 3_600_000) : null;
  if (lastAt && nextAt && nextAt > now()) {
    log(`Last fetched ${lastAt.toISOString()}; run again after ${nextAt.toISOString()}.`);
    return 2;
  }

  let data: unknown;
  try {
    data = await getOnce(deps);
  } catch (err) {
    if ((err as { http?: boolean }).http) {
      log(`AMC fetch failed: ${(err as Error).message}`);
      return 1;
    }
    log(`Network error (${(err as Error).message}); one retry in 60 s.`);
    await (deps.sleep ?? ((ms) => new Promise((r) => setTimeout(r, ms))))(RETRY_AFTER_MS);
    try {
      data = await getOnce(deps);
    } catch (err2) {
      log(`AMC fetch failed again: ${(err2 as Error).message}`);
      return 1;
    }
  }

  let rows: CcrsRow[];
  try {
    rows = validateRows(data).slice().sort((a, b) => a['row#'] - b['row#']);
  } catch (err) {
    log(`AMC response rejected: ${(err as Error).message}`);
    return 1;
  }
  const fetchedAt = now();
  const prev = fs.existsSync(file) ? loadSnapshot(file) : null;
  const snap: Snapshot = { source: deps.url, fetchedAt: fetchedAt.toISOString(), note: prev?.note, rowCount: rows.length, rows };
  fs.writeFileSync(file, `${JSON.stringify(snap, null, 2)}\n`);
  const r = await deps.prisma.$transaction((tx) => syncProblemTypes(tx, rows, fetchedAt), { timeout: 60_000 });
  report(log, r);
  return 0;
}
