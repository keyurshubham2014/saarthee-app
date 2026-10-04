// T-07-04 filters/sorts/validation, T-07-05 cursor walk, T-07-06 mine/following, T-07-14 page-size caps.
import { beforeEach, describe, expect, it } from 'vitest';
import { prisma } from '../../src/lib/db';
import { DAY, get, photoIssue, seedReference, user, ward } from './helpers';

beforeEach(async () => {
  await (await import('../helpers/db')).resetDb();
  await seedReference();
});

type Item = { id: string; categorySlug: string; status: string; isOverdue: boolean; meTooCount: number; createdAt: string; title: string; wardNameEn: string };

async function walk(query: string, limit = 7, auth?: Record<string, string>): Promise<Item[]> {
  const out: Item[] = [];
  let cursor: string | null = null;
  for (let guard = 0; guard < 200; guard++) {
    const res = await get(`/api/v1/issues?${query}&limit=${limit}${cursor ? `&cursor=${cursor}` : ''}`, auth);
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    out.push(...res.body.items);
    cursor = res.body.nextCursor;
    if (!cursor) return out;
  }
  throw new Error('cursor never ended');
}

describe('GET /issues', () => {
  it('filters by ward, category, status (incl. overdue) and bbox; card shape has no reporter data', async () => {
    const r = await user();
    const w2 = await ward(2);
    await photoIssue(r.user.id, { category: 'roads' });
    await photoIssue(r.user.id, { category: 'garbage', slaDueAt: new Date(Date.now() - DAY) });
    await photoIssue(r.user.id, { category: 'water', wardNumber: 2, lat: 23.2, lng: 72.7 });
    await photoIssue(r.user.id, { category: 'roads', status: 'verified' });
    await photoIssue(r.user.id, { status: 'rejected' });
    await photoIssue(r.user.id, { visibility: 'hidden' });

    const all = (await get('/api/v1/issues')).body.items as Item[];
    expect(all).toHaveLength(4);
    expect(Object.keys(all[0]!).sort()).toEqual(
      ['categorySlug', 'createdAt', 'displayStatus', 'id', 'isOverdue', 'meTooCount', 'pendingReview', 'status', 'thumbnailUrl', 'title', 'wardNameEn', 'wardNameGu'].sort(),
    );
    expect(JSON.stringify(all)).not.toContain(r.user.id);
    expect((await get(`/api/v1/issues?ward=${w2.id}`)).body.items.map((i: Item) => i.categorySlug)).toEqual(['water']);
    expect((await get('/api/v1/issues?category=roads,garbage')).body.items).toHaveLength(3);
    const overdue = (await get('/api/v1/issues?status=overdue')).body.items as Item[];
    expect(overdue.map((i) => i.categorySlug)).toEqual(['garbage']);
    expect(overdue[0]!.isOverdue).toBe(true);
    expect((await get('/api/v1/issues?status=verified,overdue')).body.items).toHaveLength(2);
    expect((await get('/api/v1/issues?bbox=72.69,23.19,72.71,23.21')).body.items.map((i: Item) => i.categorySlug)).toEqual(['water']);
    expect((await get('/api/v1/issues?lang=gu&category=water')).body.items[0].title).toContain('·');
  });

  it('sorts: newest, most_affected, overdue first', async () => {
    const r = await user();
    const a = await photoIssue(r.user.id, { createdAt: new Date(Date.now() - 3 * DAY), meTooCount: 9, slaDueAt: new Date(Date.now() - 2 * DAY) });
    const b = await photoIssue(r.user.id, { createdAt: new Date(Date.now() - 2 * DAY), meTooCount: 1, slaDueAt: new Date(Date.now() - 5 * DAY) });
    const c = await photoIssue(r.user.id, { createdAt: new Date(Date.now() - DAY), meTooCount: 4 });
    const ids = async (q: string) => ((await get(`/api/v1/issues?${q}`)).body.items as Item[]).map((i) => i.id);
    expect(await ids('sort=newest')).toEqual([c.issue.id, b.issue.id, a.issue.id]);
    expect(await ids('sort=most_affected')).toEqual([a.issue.id, c.issue.id, b.issue.id]);
    expect(await ids('sort=overdue')).toEqual([b.issue.id, a.issue.id]);
  });

  it('400 on bad bbox, span > 0.5°, unknown sort, bad cursor and limit > 50; 401 for mine/following signed out', async () => {
    for (const q of ['bbox=1,2,3', 'bbox=72,23,72.6,23.1', 'sort=random', 'limit=51', 'limit=0', 'cursor=nope', 'status=lost']) {
      const res = await get(`/api/v1/issues?${q}`);
      expect(res.status, q).toBe(400);
      expect(res.body.error.code).toBe('VALIDATION_FAILED');
    }
    expect((await get('/api/v1/issues?mine=true')).status).toBe(401);
    expect((await get('/api/v1/issues?following=true')).status).toBe(401);
  });

  it('cursor walk over 500 rows: no duplicate or gap for each sort, with inserts between pages', async () => {
    const r = await user();
    const w = await ward(1);
    const cat = (await prisma.category.findFirstOrThrow({ where: { slug: 'roads' } })).id;
    const base = Date.now() - 400 * DAY;
    await prisma.issue.createMany({
      data: Array.from({ length: 500 }, (_, n) => ({
        clientSubmissionId: crypto.randomUUID(), reporterId: r.user.id, categoryId: cat, title: 'Pothole', lat: 23.005, lng: 72.505,
        wardId: w.id, zoneId: w.zoneId, createdAt: new Date(base + Math.floor(n / 3) * 60_000), meTooCount: n % 7,
        slaDueAt: new Date(base + (n % 50) * DAY),
      })),
    });
    for (const sort of ['newest', 'most_affected', 'overdue'] as const) {
      const before = (await prisma.issue.findMany({ where: sort === 'overdue' ? { slaDueAt: { lt: new Date() } } : {}, select: { id: true } })).map((i) => i.id);
      const seen = new Set<string>();
      let cursor: string | null = null;
      let pages = 0;
      do {
        const res = await get(`/api/v1/issues?sort=${sort}&limit=50${cursor ? `&cursor=${cursor}` : ''}`);
        expect(res.status).toBe(200);
        for (const i of res.body.items as Item[]) {
          expect(seen.has(i.id), `${sort} duplicate`).toBe(false);
          seen.add(i.id);
        }
        cursor = res.body.nextCursor;
        // A new report between pages must not shift the walk.
        if (pages++ === 1) await photoIssue(r.user.id);
      } while (cursor);
      // Every row that existed when the walk started is seen exactly once (new rows may or may not appear).
      expect(before.filter((id) => !seen.has(id)), sort).toEqual([]);
      expect(seen.size, sort).toBeLessThanOrEqual(before.length + 1);
    }
  });

  it('mine includes own hidden and rejected issues (pendingReview); following lists followed issues', async () => {
    const me = await user();
    const other = await user();
    await photoIssue(me.user.id);
    await photoIssue(me.user.id, { visibility: 'hidden' });
    await photoIssue(me.user.id, { status: 'rejected' });
    const theirs = await photoIssue(other.user.id);
    await photoIssue(other.user.id);
    await prisma.follow.create({ data: { issueId: theirs.issue.id, userId: me.user.id } });
    const mine = await walk('mine=true', 2, me.auth);
    expect(mine).toHaveLength(3);
    expect(mine.filter((i) => (i as unknown as { pendingReview: boolean }).pendingReview)).toHaveLength(1);
    const following = await walk('following=true', 2, me.auth);
    // Own issues are auto-followed (TASK-05) plus the one followed explicitly; hidden/rejected excluded.
    expect(following.map((i) => i.id)).toContain(theirs.issue.id);
    expect(following).toHaveLength(2);
  });

  it('page size caps on issues and events lists', async () => {
    const r = await user();
    const { issue } = await photoIssue(r.user.id);
    expect((await get('/api/v1/issues?limit=50')).status).toBe(200);
    expect((await get('/api/v1/issues?limit=51')).status).toBe(400);
    expect((await get(`/api/v1/issues/${issue.id}/events?limit=51`)).status).toBe(400);
    expect((await get('/api/v1/issues?mine=true&limit=51', r.auth)).status).toBe(400);
    expect((await get('/api/v1/issues?following=true&limit=51', r.auth)).status).toBe(400);
  });
});
