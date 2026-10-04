import { defineSeedModule } from '../types';

/**
 * Zone `nameGu` already ends in "ઝોન" ("મધ્ય ઝોન"), unlike `nameEn` ("Central").
 *
 * V2 TASK-06: fictional escalation contacts for development (`@example.org`, invented landlines). Pilot data is
 * entered by staff from AMC's published pages (TASK-10/14), with source URL and verified date.
 */
const SOURCE = 'https://example.org/saarthee-dev-escalation-contacts';

export default defineSeedModule({
  name: 'escalation-contacts',
  requires: ['escalation_contacts', 'zones'],
  async run({ prisma, log }) {
    const zones = await prisma.zone.findMany({ select: { id: true, code: true, nameEn: true, nameGu: true }, orderBy: { sortOrder: 'asc' } });
    const rows = [
      ...zones.flatMap((z, i) => [
        {
          level: 'zone_office', zoneId: z.id, titleEn: `${z.nameEn} Zone office (sample)`, titleGu: `${z.nameGu} ઑફિસ (નમૂનો)`,
          email: `zone-${z.code.toLowerCase()}@example.org`, phone: `0790000${String(100 + i).padStart(4, '0')}`,
        },
        {
          level: 'deputy_commissioner', zoneId: z.id, titleEn: `Deputy Municipal Commissioner, ${z.nameEn} Zone (sample)`,
          titleGu: `ડેપ્યુટી મ્યુનિસિપલ કમિશનર, ${z.nameGu} (નમૂનો)`, email: `dmc-${z.code.toLowerCase()}@example.org`, phone: null,
        },
      ]),
      { level: 'commissioner', zoneId: null, titleEn: 'Municipal Commissioner (sample)', titleGu: 'મ્યુનિસિપલ કમિશનર (નમૂનો)', email: 'commissioner@example.org', phone: null },
    ];
    let created = 0;
    for (const r of rows) {
      if (await prisma.escalationContact.findFirst({ where: { level: r.level, zoneId: r.zoneId }, select: { id: true } })) continue;
      await prisma.escalationContact.create({ data: { ...r, sourceUrl: SOURCE, lastVerifiedAt: new Date('2026-10-01') } });
      created += 1;
    }
    log(`escalation-contacts: ${created} created`);
  },
});
