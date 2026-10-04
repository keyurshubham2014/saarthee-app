/**
 * AMC CCRS problem-type mapping and sync (V2 TASK-05 §5.2/§5.3). Pure mapping + one upsert routine
 * shared by the seed, `npm run amc:problems:fetch` and tests. Never calls the network itself.
 */
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import type { Prisma, PrismaClient } from '@prisma/client';

export const AMC_DATA_DIR = path.resolve(__dirname, '../../../prisma/data');
export const SNAPSHOT_PATH = path.join(AMC_DATA_DIR, 'amc-problem-types.snapshot.json');
export const MAP_PATH = path.join(AMC_DATA_DIR, 'amc-category-map.json');

export interface CcrsRow {
  'row#': number;
  department: string;
  problemCategory: string;
  problem: string;
  'problem in Gujarati': string;
}
export interface Snapshot {
  source: string;
  fetchedAt: string;
  note?: string;
  rowCount: number;
  rows: CcrsRow[];
}
interface Rule {
  department: string;
  problemCategory: string;
  slug: string;
}
export interface CategoryMap {
  problemOverrides: { problem: string; slug: string }[];
  rules: Rule[];
  primaries: Record<string, string>;
  deptGu: Record<string, string>;
}

const EXPECTED_KEYS = ['row#', 'department', 'problemCategory', 'problem', 'problem in Gujarati'];

export const loadSnapshot = (file = SNAPSHOT_PATH): Snapshot => JSON.parse(fs.readFileSync(file, 'utf8')) as Snapshot;
export const loadCategoryMap = (file = MAP_PATH): CategoryMap => JSON.parse(fs.readFileSync(file, 'utf8')) as CategoryMap;

const clean = (s: string) => s.replace(/\s+/g, ' ').trim();

export function sourceKey(r: Pick<CcrsRow, 'department' | 'problemCategory' | 'problem'>): string {
  return createHash('sha1').update(`${clean(r.department)}|${clean(r.problemCategory)}|${clean(r.problem)}`).digest('hex');
}

/** Validates the CCRS JSON shape: 50–500 rows, each with exactly the 5 expected keys (strings / row number). */
export function validateRows(data: unknown): CcrsRow[] {
  if (!Array.isArray(data) || data.length < 50 || data.length > 500) throw new Error(`expected 50-500 rows, got ${Array.isArray(data) ? data.length : typeof data}`);
  for (const r of data as Record<string, unknown>[]) {
    const keys = Object.keys(r ?? {}).sort();
    if (keys.join('|') !== [...EXPECTED_KEYS].sort().join('|')) throw new Error(`unexpected row keys: ${keys.join(', ')}`);
    if (typeof r.department !== 'string' || typeof r.problem !== 'string' || typeof r.problemCategory !== 'string') throw new Error('row fields must be strings');
  }
  return data as CcrsRow[];
}

export interface MappedRow {
  sourceKey: string;
  ccrsRow: number;
  slug: string;
  mapped: boolean;
  deptEn: string;
  deptGu: string;
  problemCategoryEn: string;
  problemEn: string;
  problemGu: string;
  isPrimary: boolean;
}

/** Maps one CCRS row to a Saarthee category slug (unmatched → `other`, `mapped:false`). */
export function mapRow(r: CcrsRow, map: CategoryMap): MappedRow {
  const dept = clean(r.department);
  const cat = clean(r.problemCategory);
  const problem = clean(r.problem);
  const override = map.problemOverrides.find((o) => clean(o.problem) === problem);
  const rule =
    map.rules.find((x) => x.department === dept && clean(x.problemCategory) === cat) ??
    map.rules.find((x) => x.department === dept && x.problemCategory === '*');
  const slug = override?.slug ?? rule?.slug ?? 'other';
  return {
    sourceKey: sourceKey(r),
    ccrsRow: r['row#'],
    slug,
    mapped: Boolean(override ?? rule),
    deptEn: dept,
    deptGu: map.deptGu[dept] ?? dept,
    problemCategoryEn: cat,
    problemEn: problem,
    problemGu: clean(r['problem in Gujarati'] ?? '') || problem,
    isPrimary: slug !== 'other' && clean(map.primaries[slug] ?? '') === problem,
  };
}

export interface SyncResult {
  total: number;
  created: number;
  changed: number;
  deactivated: number;
  unmapped: string[];
}

type Db = PrismaClient | Prisma.TransactionClient;

/** Upserts rows by source_key, deactivates vanished rows; returns counts (TASK-05 §5.3). */
export async function syncProblemTypes(db: Db, rows: CcrsRow[], fetchedAt: Date, map = loadCategoryMap()): Promise<SyncResult> {
  const cats = new Map((await db.category.findMany({ select: { id: true, slug: true } })).map((c) => [c.slug, c.id]));
  const mapped = rows.map((r) => mapRow(r, map));
  const existing = new Map((await db.amcProblemType.findMany()).map((p) => [p.sourceKey, p]));
  const result: SyncResult = { total: mapped.length, created: 0, changed: 0, deactivated: 0, unmapped: [] };
  // Clear primaries first so the partial unique index never sees two primaries mid-sync.
  await db.amcProblemType.updateMany({ where: { isPrimary: true }, data: { isPrimary: false } });
  for (const m of mapped) {
    if (!m.mapped) result.unmapped.push(`${m.deptEn} › ${m.problemCategoryEn} › ${m.problemEn}`);
    const categoryId = cats.get(m.slug);
    if (!categoryId) throw new Error(`category ${m.slug} is not seeded`);
    const data = {
      categoryId, ccrsRow: m.ccrsRow, deptEn: m.deptEn, deptGu: m.deptGu, problemCategoryEn: m.problemCategoryEn,
      problemEn: m.problemEn, problemGu: m.problemGu, isPrimary: m.isPrimary, isActive: true, fetchedAt,
    };
    const prev = existing.get(m.sourceKey);
    if (!prev) result.created++;
    else if (prev.categoryId !== categoryId || prev.problemGu !== m.problemGu || prev.deptGu !== m.deptGu || !prev.isActive || prev.isPrimary !== m.isPrimary) result.changed++;
    await db.amcProblemType.upsert({ where: { sourceKey: m.sourceKey }, create: { sourceKey: m.sourceKey, ...data }, update: data });
  }
  const keep = mapped.map((m) => m.sourceKey);
  const gone = await db.amcProblemType.updateMany({ where: { sourceKey: { notIn: keep }, isActive: true }, data: { isActive: false, isPrimary: false } });
  result.deactivated = gone.count;
  return result;
}
