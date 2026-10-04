// T-05-01, T-05-02, T-05-03, T-05-14 (AC-1, AC-2, AC-14): v2 categories, AMC mapping, polite fetch script.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { seedAmcProblemTypes, seedV2Categories } from '../../prisma/seed/v2-categories';
import { prisma } from '../../src/lib/db';
import { loadCategoryMap, loadSnapshot, mapRow, type CcrsRow } from '../../src/modules/categories/amc';
import { runAmcFetch } from '../../src/modules/categories/amc-fetch';
import { api } from '../helpers/app';
import { resetDb } from '../helpers/db';

beforeEach(async () => {
  await resetDb();
  await seedV2Categories(prisma);
  await seedAmcProblemTypes(prisma);
});

describe('GET /categories (T-05-01)', () => {
  it('returns 14 categories in order with AMC types, one primary per non-other category, and 304 on ETag', async () => {
    const res = await api().get('/api/v1/categories');
    expect(res.status).toBe(200);
    const items = res.body.items as { slug: string; sortOrder: number; amcProblemTypes: { isPrimary: boolean; deptGu: string }[] }[];
    expect(items).toHaveLength(14);
    expect(items.map((c) => c.slug)).toEqual(['roads', 'water', 'drainage', 'garbage', 'streetlight', 'trees', 'animals', 'health', 'toilets', 'encroachment', 'traffic', 'property', 'building', 'other']);
    expect(items[0]).toMatchObject({ nameEn: 'Roads & potholes', nameGu: 'રસ્તા અને ખાડા', icon: 'road', colourToken: 'category.roads', slaDays: 7, sensitive: false, sortOrder: 1 });
    expect(items.find((c) => c.slug === 'encroachment')).toMatchObject({ sensitive: true, slaDays: 15 });
    for (const c of items.filter((x) => x.slug !== 'other')) {
      expect(c.amcProblemTypes.length).toBeGreaterThan(0);
      expect(c.amcProblemTypes.filter((p) => p.isPrimary)).toHaveLength(1);
      expect(c.amcProblemTypes[0]!.isPrimary).toBe(true);
    }
    expect(items[0]!.amcProblemTypes[0]).toMatchObject({ deptEn: 'Engineering', problemEn: 'Road-Repair Require', deptGu: 'ઇજનેર વિભાગ' });
    const etag = res.headers.etag as string;
    expect(etag).toMatch(/^W\//);
    expect((await api().get('/api/v1/categories').set('If-None-Match', etag)).status).toBe(304);
  });
});

describe('AMC mapping (T-05-02)', () => {
  it('maps all 113 snapshot rows (22 departments) to a seeded category', async () => {
    const snap = loadSnapshot();
    expect(snap.rows).toHaveLength(113);
    expect(new Set(snap.rows.map((r) => r.department)).size).toBe(22);
    expect(await prisma.amcProblemType.count({ where: { isActive: true } })).toBe(113);
    const map = loadCategoryMap();
    for (const dept of new Set(snap.rows.map((r) => r.department.trim()))) expect(map.deptGu[dept]).toBeTruthy();
    // Every row matches an explicit rule (none falls through to `other` by accident).
    expect(snap.rows.map((r) => mapRow(r, map)).filter((m) => !m.mapped)).toEqual([]);
    const other = snap.rows.map((r) => mapRow(r, map)).filter((m) => m.slug === 'other');
    expect(other.every((m) => !m.isPrimary)).toBe(true);
  });

  it('sends an unknown department to other', () => {
    const row: CcrsRow = { 'row#': 999, department: 'Zoo', problemCategory: 'Animals', problem: 'Cage broken', 'problem in Gujarati': 'પાંજરું તૂટ્યું' };
    expect(mapRow(row, loadCategoryMap())).toMatchObject({ slug: 'other', mapped: false, isPrimary: false, deptGu: 'Zoo' });
  });
});

describe('amc:problems:fetch (T-05-03)', () => {
  const base = { url: 'https://example.invalid/amc', minIntervalHours: 24, contactEmail: 'ops@example.com', log: () => {} };
  const tmpSnapshot = () => {
    const file = path.join(fs.mkdtempSync(path.join(os.tmpdir(), 'amc-')), 'snap.json');
    fs.copyFileSync(path.resolve(__dirname, '../../prisma/data/amc-problem-types.snapshot.json'), file);
    return file;
  };

  it('refuses within the interval without any request', async () => {
    const fetchImpl = vi.fn();
    const now = () => new Date(new Date(loadSnapshot().fetchedAt).getTime() + 3_600_000);
    const code = await runAmcFetch({ ...base, prisma, fromSnapshot: false, fetchImpl: fetchImpl as unknown as typeof fetch, now, snapshotPath: tmpSnapshot() });
    expect(code).toBe(2);
    expect(fetchImpl).not.toHaveBeenCalled();
  });

  it('after the interval makes exactly one request, rewrites the snapshot, upserts and deactivates vanished rows', async () => {
    const rows = loadSnapshot().rows.slice(1).map((r) => ({ ...r }));
    rows.push({ 'row#': 500, department: 'Zoo', problemCategory: 'Animals', problem: 'Cage broken', 'problem in Gujarati': 'પાંજરું' });
    const fetchImpl = vi.fn(async () => new Response(JSON.stringify(rows), { status: 200, headers: { 'content-type': 'application/json' } }));
    const file = tmpSnapshot();
    const lines: string[] = [];
    const now = () => new Date(Date.now() + 2 * 86_400_000);
    const code = await runAmcFetch({ ...base, prisma, fromSnapshot: false, fetchImpl: fetchImpl as unknown as typeof fetch, now, snapshotPath: file, log: (l) => lines.push(l) });
    expect(code).toBe(0);
    expect(fetchImpl).toHaveBeenCalledTimes(1);
    expect(JSON.parse(fs.readFileSync(file, 'utf8')).rowCount).toBe(113);
    expect(await prisma.amcProblemType.count({ where: { isActive: false } })).toBe(1);
    expect(lines.join('\n')).toMatch(/new 1, .*deactivated 1, unmapped 1/);
    expect(lines.join('\n')).toContain('Zoo › Animals › Cage broken');
  });

  it('--from-snapshot never touches the network', async () => {
    const fetchImpl = vi.fn();
    const code = await runAmcFetch({ ...base, prisma, fromSnapshot: true, fetchImpl: fetchImpl as unknown as typeof fetch, snapshotPath: tmpSnapshot() });
    expect(code).toBe(0);
    expect(fetchImpl).not.toHaveBeenCalled();
  });

  it('rejects a response with an unexpected shape', async () => {
    const fetchImpl = vi.fn(async () => new Response(JSON.stringify([{ a: 1 }]), { status: 200 }));
    const now = () => new Date(Date.now() + 2 * 86_400_000);
    const code = await runAmcFetch({ ...base, prisma, fromSnapshot: false, fetchImpl: fetchImpl as unknown as typeof fetch, now, snapshotPath: tmpSnapshot() });
    expect(code).toBe(1);
  });
});

describe('v1 POST /reports retired (T-05-14)', () => {
  it('answers 410 ENDPOINT_RETIRED', async () => {
    const res = await api().post('/api/v1/reports').send({});
    expect(res.status).toBe(410);
    expect(res.body.error).toMatchObject({ code: 'ENDPOINT_RETIRED', message: 'Please update Saarthee to report issues.' });
  });
});
