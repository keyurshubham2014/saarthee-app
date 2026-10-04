import { prisma } from '../../lib/db';
import { checkUrl, type CheckOptions, type CheckResult } from '../../lib/linkcheck';

export interface LinkRow {
  slug: string;
  url: string;
  ok: boolean;
  statusCode: number | null;
  error: string | null;
}

export interface RunOptions extends CheckOptions {
  concurrency?: number;
  /** Minimum gap between two requests to the same host (default 1 s). */
  perHostGapMs?: number;
  now?: () => Date;
}

async function store(id: string, r: CheckResult, at: Date) {
  await prisma.service.update({
    where: { id },
    data: { linkOk: r.ok, linkStatusCode: r.statusCode, linkError: r.error, lastCheckedAt: at },
  });
}

/** Checks one service now (staff "Check link now") and stores the outcome. */
export async function checkServiceLink(id: string, url: string, opts: RunOptions = {}) {
  const r = await checkUrl(url, opts);
  const checkedAt = (opts.now ?? (() => new Date()))();
  await store(id, r, checkedAt);
  return { linkOk: r.ok, statusCode: r.statusCode, error: r.error, checkedAt };
}

/**
 * `npm run services:check-links` body: every active service, concurrency 2, ≥ 1 s between requests to
 * one host. Broken links are data — this never throws for them (only for database errors).
 */
export async function checkAllServiceLinks(opts: RunOptions = {}): Promise<LinkRow[]> {
  const sleep = opts.sleep ?? ((ms: number) => new Promise<void>((r) => setTimeout(r, ms)));
  const gap = opts.perHostGapMs ?? 1_000;
  const services = await prisma.service.findMany({ where: { isActive: true }, orderBy: [{ category: 'asc' }, { sortOrder: 'asc' }] });
  const nextSlot = new Map<string, number>();
  const rows: LinkRow[] = [];
  let index = 0;

  async function reserve(host: string) {
    const now = Date.now();
    const at = Math.max(now, nextSlot.get(host) ?? 0);
    nextSlot.set(host, at + gap);
    if (at > now) await sleep(at - now);
  }

  async function worker() {
    while (index < services.length) {
      const s = services[index++]!;
      let host = s.url;
      try {
        host = new URL(s.url).host;
      } catch {
        // stored URLs are CHECKed to https://, so this is unreachable in practice
      }
      await reserve(host);
      const r = await checkUrl(s.url, opts);
      await store(s.id, r, (opts.now ?? (() => new Date()))());
      rows.push({ slug: s.slug, url: s.url, ok: r.ok, statusCode: r.statusCode, error: r.error });
    }
  }

  await Promise.all(Array.from({ length: Math.max(1, opts.concurrency ?? 2) }, worker));
  return rows.sort((a, b) => a.slug.localeCompare(b.slug));
}

/** Plain-text summary table printed by the script. */
export function summaryTable(rows: LinkRow[]): string {
  const lines = rows.map((r) => `${r.ok ? 'OK    ' : 'BROKEN'}  ${String(r.statusCode ?? '-').padEnd(4)} ${(r.error ?? '').padEnd(20)} ${r.slug}  ${r.url}`);
  const broken = rows.filter((r) => !r.ok).length;
  return [...lines, `${rows.length} checked, ${rows.length - broken} ok, ${broken} broken`].join('\n');
}
