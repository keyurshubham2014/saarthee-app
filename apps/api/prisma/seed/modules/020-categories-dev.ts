import { defineSeedModule } from '../types';

/**
 * DEVELOPMENT fixture of the 14 v2 categories (Spec §4): icon = slug, colour token cat_<slug>, SLA 7 days.
 * TASK-05 replaces this with the reviewed reference data (names, SLAs, sensitive flags, AMC mapping).
 */
export const DEV_CATEGORIES: readonly { slug: string; nameEn: string; nameGu: string }[] = [
  { slug: 'roads', nameEn: 'Roads & potholes', nameGu: 'રસ્તા અને ખાડા' },
  { slug: 'water', nameEn: 'Water supply', nameGu: 'પાણી પુરવઠો' },
  { slug: 'drainage', nameEn: 'Drainage & waterlogging', nameGu: 'ગટર અને પાણી ભરાવો' },
  { slug: 'garbage', nameEn: 'Garbage & cleanliness', nameGu: 'કચરો અને સફાઈ' },
  { slug: 'streetlight', nameEn: 'Streetlights', nameGu: 'સ્ટ્રીટલાઇટ' },
  { slug: 'trees', nameEn: 'Trees & parks', nameGu: 'વૃક્ષો અને બગીચા' },
  { slug: 'animals', nameEn: 'Stray animals', nameGu: 'રખડતાં પશુઓ' },
  { slug: 'health', nameEn: 'Mosquitoes & health', nameGu: 'મચ્છર અને આરોગ્ય' },
  { slug: 'toilets', nameEn: 'Public toilets', nameGu: 'જાહેર શૌચાલય' },
  { slug: 'encroachment', nameEn: 'Encroachment', nameGu: 'દબાણ' },
  { slug: 'traffic', nameEn: 'Traffic & parking', nameGu: 'ટ્રાફિક અને પાર્કિંગ' },
  { slug: 'property', nameEn: 'Property & tax', nameGu: 'મિલકત અને વેરો' },
  { slug: 'building', nameEn: 'Building & construction', nameGu: 'બાંધકામ' },
  { slug: 'other', nameEn: 'Other', nameGu: 'અન્ય' },
];

export default defineSeedModule({
  name: 'categories-dev',
  requires: ['categories'],
  async run({ prisma }) {
    const existing = new Set((await prisma.category.findMany({ select: { slug: true } })).map((c) => c.slug));
    const missing = DEV_CATEGORIES.map((c, i) => ({ ...c, sortOrder: (i + 1) * 10 })).filter((c) => !existing.has(c.slug));
    if (missing.length === 0) return;
    await prisma.category.createMany({
      data: missing.map((c) => ({
        slug: c.slug,
        nameEn: c.nameEn,
        nameGu: c.nameGu,
        icon: c.slug,
        colourToken: `cat_${c.slug}`,
        slaDays: 7,
        sortOrder: c.sortOrder,
      })),
    });
  },
});
