// T-11-06 dashboard numbers (AC-6), T-11-07 scope (AC-7), T-11-08 CSV (AC-8), T-11-16 neutrality (AC-12).
import type { IssueStatus } from '@prisma/client';
import { beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { captureAudit } from '../../src/lib/audit';
import { csvRow } from '../../src/lib/csv';
import { prisma } from '../../src/lib/db';
import { resetRateLimitStores } from '../../src/middleware/rateLimit';
import { WARD_CSV_COLUMNS } from '../../src/modules/ward-dashboard/ward.service';
import { resetDb } from '../helpers/db';
import { makeCategory } from '../helpers/factories';
import { issueInWard } from '../staff/helpers';
import { fixtureWards, makeAc, makeRep } from './helpers';
import { get, signed, verifiedRep } from './t11-helpers';

const DAY = 86_400_000;
let wards: Map<number, string>;
let rep: Awaited<ReturnType<typeof verifiedRep>>;
let mla: Awaited<ReturnType<typeof signed>>;
const ago = (d: number) => new Date(Date.now() - d * DAY);

async function fixture() {
  const roads = await makeCategory({ slug: 'roads', sortOrder: 1 });
  const water = await makeCategory({ slug: 'water', sortOrder: 2 });
  const add = (days: number, categoryId: string, extra: { status?: IssueStatus; overdue?: boolean; title?: string; visibility?: 'hidden' } = {}) =>
    issueInWard(1, {
      categoryId, createdAt: ago(days), status: extra.status ?? 'reported', title: extra.title ?? 'Pothole',
      slaDueAt: extra.overdue ? ago(1) : new Date(Date.now() + 5 * DAY), visibility: extra.visibility ?? 'public', reporterId: null,
    });
  for (let i = 0; i < 3; i++) await add(2, i < 2 ? roads.id : water.id);
  for (let i = 0; i < 4; i++) await add(15, i < 3 ? roads.id : water.id, { status: 'acknowledged', overdue: i === 0 });
  for (let i = 0; i < 2; i++) await add(45, roads.id, { status: 'in_progress', overdue: true, title: i === 0 ? '=HYPERLINK("x")' : 'Drain' });
  await add(3, roads.id, { visibility: 'hidden' });
  await add(3, roads.id, { status: 'rejected' });
  const fixed = await add(20, water.id, { status: 'verified' });
  await prisma.issueEvent.createMany({
    data: [
      { issueId: fixed.id, actorRole: 'representative', type: 'status_change', fromStatus: 'acknowledged', toStatus: 'marked_fixed', createdAt: ago(10) },
      { issueId: fixed.id, actorRole: 'system', type: 'status_change', fromStatus: 'marked_fixed', toStatus: 'verified', createdAt: ago(8) },
    ],
  });
  await issueInWard(2, { categoryId: roads.id, title: 'Other ward' });
}

beforeAll(async () => {
  await resetDb();
  wards = await fixtureWards();
  await fixture();
  rep = await verifiedRep([wards.get(1)!], { partyText: 'Party A' });
  mla = await signed('representative');
  const ac = await makeAc(41, [wards.get(2)!, wards.get(3)!]);
  await makeRep({ role: 'mla', userId: mla.user.id, verifiedAt: new Date() }, [{ assemblyConstituencyId: ac.id }]);
});
beforeEach(() => resetRateLimitStores());

describe('ward dashboard numbers (T-11-06)', () => {
  it('matches the fixture exactly and excludes hidden/rejected; no reporter data', async () => {
    const res = await get(rep.auth, `/staff/ward-dashboard?ward=${wards.get(1)}`);
    expect(res.status).toBe(200);
    const b = res.body;
    expect(b.ward).toMatchObject({ id: wards.get(1), number: 1 });
    expect(b.totals).toEqual({ open: 9, overdue: 3, markedFixed30d: 1, verified30d: 1 });
    expect(b.byCategory).toEqual([
      { slug: 'roads', d0_7: 2, d8_30: 3, d31Plus: 2, total: 7 },
      { slug: 'water', d0_7: 1, d8_30: 1, d31Plus: 0, total: 2 },
    ]);
    expect(b.overdue).toHaveLength(3);
    expect(b.overdue.map((o: { ageDays: number }) => o.ageDays).sort()).toEqual([15, 45, 45]);
    expect(b.hotspots).toEqual([{ lat: expect.any(Number), lng: expect.any(Number), count: 9 }]);
    expect(b.trend).toHaveLength(12);
    const sum = (k: string) => b.trend.reduce((s: number, w: Record<string, number>) => s + w[k]!, 0);
    expect(sum('markedFixed')).toBe(1);
    expect(sum('verified')).toBe(1);
    expect(sum('reported')).toBe(10); // 9 open + 1 verified, all created within 12 weeks
    expect(b.electionMode).toEqual({ active: false, until: null });
    const text = JSON.stringify(b);
    for (const bad of ['reporter', 'phone', 'description', 'photo']) expect(text).not.toContain(bad);
  });
});

describe('scope (T-11-07)', () => {
  it('corporator: other ward 403 on dashboard, export, list; MLA sees constituency wards; moderator any ward', async () => {
    for (const path of [`/staff/ward-dashboard?ward=${wards.get(2)}`, `/staff/ward-dashboard/export?ward=${wards.get(2)}&from=2026-01-01&to=2026-12-31`, `/staff/ward/issues?ward=${wards.get(2)}`]) {
      const r = await get(rep.auth, path);
      expect([path, r.status, r.body.error?.code]).toEqual([path, 403, 'WARD_OUT_OF_SCOPE']);
    }
    expect((await get(rep.auth, '/staff/ward/scope')).body.items.map((w: { number: number }) => w.number)).toEqual([1]);
    expect((await get(mla.auth, '/staff/ward/scope')).body.items.map((w: { number: number }) => w.number)).toEqual([2, 3]);
    expect((await get(mla.auth, `/staff/ward-dashboard?ward=${wards.get(2)}`)).status).toBe(200);
    expect((await get(mla.auth, `/staff/ward-dashboard?ward=${wards.get(1)}`)).status).toBe(403);
    const mod = await signed('moderator');
    expect((await get(mod.auth, `/staff/ward-dashboard?ward=${wards.get(2)}`)).status).toBe(200);
    expect((await get(mod.auth, '/staff/ward/scope')).body.items).toHaveLength(3);
    expect((await get((await signed('citizen')).auth, `/staff/ward-dashboard?ward=${wards.get(1)}`)).status).toBe(403);
  });

  it('ward issue list carries allowedActions from the representative rules', async () => {
    const res = await get(rep.auth, `/staff/ward/issues?ward=${wards.get(1)}&limit=50`);
    expect(res.status).toBe(200);
    const by = (s: string) => res.body.items.find((i: { status: string }) => i.status === s);
    expect(by('reported').allowedActions).toEqual(['acknowledge', 'mark_fixed', 'comment']);
    expect(by('in_progress').allowedActions).toEqual(['mark_fixed', 'comment']);
    expect(by('verified').allowedActions).toEqual(['comment']);
    expect(res.body.items.some((i: { status: string }) => i.status === 'rejected')).toBe(false);
    const overdue = await get(rep.auth, `/staff/ward/issues?ward=${wards.get(1)}&overdue=true`);
    expect(overdue.body.items).toHaveLength(3);
  });
});

describe('CSV export (T-11-08)', () => {
  it('fixed columns, formula-safe, no PII, audited with row count, 11th per hour 429', async () => {
    const from = new Date(Date.now() - 90 * DAY).toISOString().slice(0, 10);
    const to = new Date(Date.now() + DAY).toISOString().slice(0, 10);
    const path = `/staff/ward-dashboard/export?ward=${wards.get(1)}&from=${from}&to=${to}`;
    const audit = captureAudit();
    const res = await get(rep.auth, path);
    audit.stop();
    expect(res.status).toBe(200);
    expect(res.headers['content-type']).toBe('text/csv; charset=utf-8');
    expect(res.headers['content-disposition']).toMatch(/^attachment; filename="saarthee-ward-1-\d{8}\.csv"$/);
    const lines = res.text.trim().split('\r\n');
    expect(lines[0]).toBe(WARD_CSV_COLUMNS.map((c) => `"${c}"`).join(','));
    expect(lines).toHaveLength(1 + 10); // 9 open + 1 verified; hidden and rejected excluded
    expect(res.text).not.toMatch(/HYPERLINK|Pothole|\+91/);
    expect(audit.lines).toEqual([expect.objectContaining({ action: 'ward_export', role: 'representative', targetType: 'ward', extra: { rows: 10 } })]);
    for (let i = 0; i < 9; i++) expect((await get(rep.auth, path)).status).toBe(200);
    expect((await get(rep.auth, path)).status).toBe(429);
    expect((await get(rep.auth, `/staff/ward-dashboard/export?ward=${wards.get(1)}&from=2025-01-01&to=2026-12-31`)).status).toBe(400);
  });

  it('a description starting with = never reaches the file; cells are formula-safe (csvRow)', async () => {
    const one = await prisma.issue.findFirstOrThrow({ where: { wardId: wards.get(1), status: 'reported' } });
    await prisma.issue.update({ where: { id: one.id }, data: { description: '=SUM(A1:A9)' } });
    const mod = await signed('moderator');
    const res = await get(mod.auth, `/staff/ward-dashboard/export?ward=${wards.get(1)}&from=2026-01-01&to=2026-12-31`);
    expect(res.status).toBe(200);
    expect(res.text).not.toContain('SUM(');
    expect(csvRow(['=cmd', '+1', 'ok'])).toBe(`"'=cmd","'+1","ok"\r\n`);
  });
});

describe('neutrality (T-11-16)', () => {
  it('dashboard and profile payloads have identical shape for representatives of different parties', async () => {
    const other = await verifiedRep([wards.get(3)!], { partyText: 'Party B' });
    const shape = (v: unknown): unknown => (Array.isArray(v) ? (v.length ? [shape(v[0])] : []) : v && typeof v === 'object' ? Object.fromEntries(Object.entries(v).map(([k, x]) => [k, shape(x)]).sort()) : typeof v);
    const a = await get(rep.auth, `/staff/ward-dashboard?ward=${wards.get(1)}`);
    const b = await get(other.auth, `/staff/ward-dashboard?ward=${wards.get(3)}`);
    expect(Object.keys(a.body).sort()).toEqual(Object.keys(b.body).sort());
    expect(shape(a.body.totals)).toEqual(shape(b.body.totals));
    expect(JSON.stringify(a.body)).not.toMatch(/party|rank/i);
    const pa = await get(undefined, `/representatives/${rep.rep.id}`);
    const pb = await get(undefined, `/representatives/${other.rep.id}`);
    expect(shape(pa.body)).toEqual(shape(pb.body));
  });
});
