import { defineSeedModule } from '../types';

/**
 * V2 TASK-09 dev seed: FICTIONAL "Sample" representatives for the 5 pilot wards (6 Nava Vadaj, 9 Naranpura,
 * 18 Navrangpura, 30 Paldi, 31 Vasna) — 4 corporators each, 3 sample assembly constituencies (Paldi spans two),
 * 3 MLAs and 1 MP. Every name says "Sample"; emails use the reserved example.org domain; the only phone numbers
 * are fictional 079 0000 00NN office landlines. No real person, party or number. The real 2026–31 roster is
 * Deferred — roster compilation (TASK-09 §13). Election mode is seeded off. Idempotent (fixed UUIDs, upserts).
 */
const SOURCE = 'https://example.org/saarthee-sample-roster';
const VERIFIED = new Date('2026-09-12T00:00:00.000Z');
const TERM_START = new Date('2026-03-01T00:00:00.000Z');
const TERM_END = new Date('2031-02-28T00:00:00.000Z');
const PILOT_WARDS = [6, 9, 18, 30, 31];
const LETTERS = ['A', 'B', 'C', 'D'];
const GU_LETTERS = ['ક', 'ખ', 'ગ', 'ઘ'];
// party_text is one column shown in both app languages, so sample parties carry both.
const PARTY_ONE = 'નમૂના પક્ષ 1 / Sample Party One';
const PARTY_TWO = 'નમૂના પક્ષ 2 / Sample Party Two';
const PARTIES = [PARTY_ONE, PARTY_TWO, 'અપક્ષ / Independent', PARTY_ONE];
const ACS = [
  { number: 901, nameEn: 'Sample Constituency North', nameGu: 'નમૂના મતવિસ્તાર ઉત્તર', short: { en: 'North', gu: 'ઉત્તર' }, wards: [18, 30] },
  { number: 902, nameEn: 'Sample Constituency South', nameGu: 'નમૂના મતવિસ્તાર દક્ષિણ', short: { en: 'South', gu: 'દક્ષિણ' }, wards: [30, 31] },
  { number: 903, nameEn: 'Sample Constituency West', nameGu: 'નમૂના મતવિસ્તાર પશ્ચિમ', short: { en: 'West', gu: 'પશ્ચિમ' }, wards: [6, 9] },
];

/** Fixed v4-shaped UUIDs: 00000009-<ward>-4000-8000-<n>. */
const rid = (group: number, n: number) => `00000009-${String(group).padStart(4, '0')}-4000-8000-${String(n).padStart(12, '0')}`;

export default defineSeedModule({
  name: 'representatives',
  requires: ['representatives', 'assembly_constituencies', 'ward_constituency', 'app_settings', 'wards'],
  async run({ prisma, log }) {
    const wards = new Map((await prisma.ward.findMany({ select: { id: true, number: true } })).map((w) => [w.number, w.id]));
    let reps = 0;
    const acIds = new Map<number, number>();
    for (const ac of ACS) {
      const data = { nameEn: ac.nameEn, nameGu: ac.nameGu, pcNameEn: 'Sample Lok Sabha Seat', pcNameGu: 'નમૂના લોકસભા બેઠક', sourceUrl: SOURCE };
      const row = await prisma.assemblyConstituency.upsert({ where: { number: ac.number }, create: { number: ac.number, ...data }, update: data });
      acIds.set(ac.number, row.id);
      for (const w of ac.wards) {
        const wardId = wards.get(w);
        if (!wardId) continue;
        await prisma.wardConstituency.upsert({
          where: { wardId_assemblyConstituencyId: { wardId, assemblyConstituencyId: row.id } },
          create: { wardId, assemblyConstituencyId: row.id, sourceUrl: SOURCE },
          update: {},
        });
      }
    }

    const upsertRep = async (id: string, data: Parameters<typeof prisma.representative.create>[0]['data'], areas: { wardId?: string; assemblyConstituencyId?: number }[]) => {
      // Create-if-missing: a second run must change nothing (updated_at included).
      await prisma.representative.upsert({ where: { id }, create: { id, ...data }, update: {} });
      for (const a of areas) {
        const exists = await prisma.representativeArea.findFirst({ where: { representativeId: id, ...a } });
        if (!exists) await prisma.representativeArea.create({ data: { representativeId: id, ...a } });
      }
      reps += 1;
    };

    for (const n of PILOT_WARDS) {
      const wardId = wards.get(n);
      if (!wardId) continue;
      for (let i = 0; i < 4; i++) {
        await upsertRep(
          rid(n, i + 1),
          {
            nameEn: `Sample Corporator ${n}-${LETTERS[i]}`,
            nameGu: `નમૂના કોર્પોરેટર ${n}-${GU_LETTERS[i]}`,
            role: 'corporator',
            partyText: PARTIES[i]!,
            termStart: TERM_START,
            termEnd: TERM_END,
            // Fictional 079 office landline on the first seat only; the last Paldi seat has no email
            // (shows the "no official email" state).
            publicPhone: i === 0 ? `+91790000${String(n).padStart(2, '0')}0${i + 1}` : null,
            publicEmail: n === 30 && i === 3 ? null : `sample.ward${n}.${LETTERS[i]!.toLowerCase()}@example.org`,
            sourceUrl: SOURCE,
            lastVerifiedAt: VERIFIED,
          },
          [{ wardId }],
        );
      }
    }
    for (const [i, ac] of ACS.entries()) {
      await upsertRep(
        rid(900, i + 1),
        {
          nameEn: `Sample MLA ${ac.short.en}`,
          nameGu: `નમૂના ધારાસભ્ય ${ac.short.gu}`,
          role: 'mla',
          partyText: PARTIES[i]!,
          termStart: new Date('2022-12-08T00:00:00.000Z'),
          termEnd: new Date('2027-12-07T00:00:00.000Z'),
          publicEmail: `sample.mla${i + 1}@example.org`,
          sourceUrl: SOURCE,
          lastVerifiedAt: VERIFIED,
        },
        [{ assemblyConstituencyId: acIds.get(ac.number)! }],
      );
    }
    await upsertRep(
      rid(900, 99),
      {
        nameEn: 'Sample MP Ahmedabad',
        nameGu: 'નમૂના સાંસદ અમદાવાદ',
        role: 'mp',
        partyText: PARTY_TWO,
        termStart: new Date('2024-06-04T00:00:00.000Z'),
        termEnd: new Date('2029-06-03T00:00:00.000Z'),
        publicEmail: 'sample.mp@example.org',
        sourceUrl: SOURCE,
        lastVerifiedAt: VERIFIED,
      },
      ACS.map((ac) => ({ assemblyConstituencyId: acIds.get(ac.number)! })),
    );

    const off = { enabled: false, scope: 'city', wardIds: [], from: '2026-01-01T00:00:00.000Z', to: '2026-01-02T00:00:00.000Z', note_en: '', note_gu: '' };
    await prisma.appSetting.upsert({ where: { key: 'election_mode' }, create: { key: 'election_mode', value: off }, update: {} });
    await prisma.$executeRawUnsafe('REFRESH MATERIALIZED VIEW ward_scorecard_mv');
    log(`Seed representatives: ${reps} Sample representatives, ${ACS.length} sample constituencies, election mode off, scorecard refreshed`);
  },
});
