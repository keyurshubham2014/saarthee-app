/**
 * The 14 v2 categories (Spec §4, V2 TASK-05 §5.2) and the AMC CCRS problem-type mapping from the committed
 * snapshot. Idempotent: categories upsert by slug, problem types by source_key. Used by the seed module
 * `categories-dev` (db:seed / demo:reset) and by tests. Gujarati names await native review.
 */
import type { PrismaClient } from '@prisma/client';
import { loadSnapshot, syncProblemTypes, type SyncResult } from '../../src/modules/categories/amc';

export interface CategoryDef {
  slug: string;
  nameEn: string;
  nameGu: string;
  icon: string;
  slaDays: number;
  sensitive: boolean;
}

export const V2_CATEGORIES: readonly CategoryDef[] = [
  { slug: 'roads', nameEn: 'Roads & potholes', nameGu: 'રસ્તા અને ખાડા', icon: 'road', slaDays: 7, sensitive: false },
  { slug: 'water', nameEn: 'Water supply', nameGu: 'પાણી પુરવઠો', icon: 'water_drop', slaDays: 2, sensitive: false },
  { slug: 'drainage', nameEn: 'Drainage & waterlogging', nameGu: 'ગટર અને પાણી ભરાવો', icon: 'water_damage', slaDays: 3, sensitive: false },
  { slug: 'garbage', nameEn: 'Garbage & cleanliness', nameGu: 'કચરો અને સફાઈ', icon: 'delete', slaDays: 2, sensitive: false },
  { slug: 'streetlight', nameEn: 'Streetlights', nameGu: 'સ્ટ્રીટલાઇટ', icon: 'lightbulb', slaDays: 3, sensitive: false },
  { slug: 'trees', nameEn: 'Trees & parks', nameGu: 'વૃક્ષો અને બગીચા', icon: 'park', slaDays: 7, sensitive: false },
  { slug: 'animals', nameEn: 'Stray animals', nameGu: 'રખડતાં પશુઓ', icon: 'pets', slaDays: 3, sensitive: false },
  { slug: 'health', nameEn: 'Mosquitoes & health', nameGu: 'મચ્છર અને આરોગ્ય', icon: 'pest_control', slaDays: 3, sensitive: false },
  { slug: 'toilets', nameEn: 'Public toilets', nameGu: 'જાહેર શૌચાલય', icon: 'wc', slaDays: 2, sensitive: false },
  { slug: 'encroachment', nameEn: 'Encroachment', nameGu: 'દબાણ', icon: 'do_not_step', slaDays: 15, sensitive: true },
  { slug: 'traffic', nameEn: 'Traffic & parking', nameGu: 'ટ્રાફિક અને પાર્કિંગ', icon: 'traffic', slaDays: 7, sensitive: false },
  { slug: 'property', nameEn: 'Property & tax', nameGu: 'મિલકત અને વેરો', icon: 'receipt_long', slaDays: 15, sensitive: false },
  { slug: 'building', nameEn: 'Building & construction', nameGu: 'બાંધકામ', icon: 'apartment', slaDays: 30, sensitive: true },
  { slug: 'other', nameEn: 'Other', nameGu: 'અન્ય', icon: 'more_horiz', slaDays: 7, sensitive: false },
];

export async function seedV2Categories(prisma: PrismaClient): Promise<void> {
  for (const [i, c] of V2_CATEGORIES.entries()) {
    const data = {
      nameEn: c.nameEn, nameGu: c.nameGu, icon: c.icon, colourToken: `category.${c.slug}`,
      slaDays: c.slaDays, sensitive: c.sensitive, sortOrder: i + 1, isActive: true,
    };
    const prev = await prisma.category.findUnique({ where: { slug: c.slug } });
    const same = prev && Object.entries(data).every(([k, v]) => (prev as Record<string, unknown>)[k] === v);
    if (!same) await prisma.category.upsert({ where: { slug: c.slug }, create: { slug: c.slug, ...data }, update: data });
  }
}

/** Seeds problem types from the committed snapshot (no network) and checks one primary per category except `other`. */
export async function seedAmcProblemTypes(prisma: PrismaClient): Promise<SyncResult> {
  const snap = loadSnapshot();
  const already = await prisma.amcProblemType.count({ where: { isActive: true } });
  const fetchedAt = new Date(snap.fetchedAt);
  const result =
    already === snap.rows.length && (await prisma.amcProblemType.count({ where: { fetchedAt } })) === already
      ? { total: already, created: 0, changed: 0, deactivated: 0, unmapped: [] }
      : await prisma.$transaction((tx) => syncProblemTypes(tx, snap.rows, fetchedAt), { timeout: 60_000 });
  const primaries = await prisma.amcProblemType.groupBy({ by: ['categoryId'], where: { isPrimary: true }, _count: true });
  const nonOther = await prisma.category.count({ where: { slug: { in: V2_CATEGORIES.filter((c) => c.slug !== 'other').map((c) => c.slug) } } });
  if (primaries.length !== nonOther) throw new Error(`expected ${nonOther} primary AMC problems, found ${primaries.length}`);
  return result;
}
