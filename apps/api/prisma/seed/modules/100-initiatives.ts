import type { PrismaClient } from '@prisma/client';
import { seedUserId } from './040-citizens';
import { PILOT_POINTS } from './050-issues';
import { defineSeedModule } from '../types';

export const seedInitiativeId = (n: number) => `5eed0012-0000-4000-8000-0000000002${String(n).padStart(2, '0')}`;

type Where = keyof typeof PILOT_POINTS | null;

/** Fictional sample drives (V2 TASK-12 §6 step 2): one per type, one full, one cancelled, one past, one draft. */
const SAMPLES: {
  n: number;
  where: Where;
  type: string;
  organiser: string;
  organiserName: string;
  titleEn: string;
  titleGu: string;
  placeEn: string;
  placeGu: string;
  inDays: number;
  hours: number;
  capacity: number | null;
  status: string;
  going: { nn: number; status: string }[];
}[] = [
  { n: 1, where: 'paldi', type: 'tree_drive', organiser: 'RWA', organiserName: "Paldi Residents' Association (નમૂનો / sample)", titleEn: 'Tree planting on the canal road (sample)', titleGu: 'કેનાલ રોડ પર વૃક્ષારોપણ (નમૂનો)', placeEn: 'Canal road garden gate, Paldi', placeGu: 'કેનાલ રોડ બગીચાનો દરવાજો, પાલડી', inDays: 5, hours: 2, capacity: 40, status: 'published', going: [{ nn: 21, status: 'going' }, { nn: 22, status: 'going' }] },
  { n: 2, where: 'navrangpura', type: 'cleanup', organiser: 'NGO', organiserName: 'Clean Lanes Trust (નમૂનો / sample)', titleEn: 'Saturday lane clean-up (sample)', titleGu: 'શનિવારે શેરી સફાઈ (નમૂનો)', placeEn: 'Community hall, Navrangpura', placeGu: 'કોમ્યુનિટી હોલ, નવરંગપુરા', inDays: 3, hours: 2, capacity: 2, status: 'published', going: [{ nn: 23, status: 'going' }, { nn: 24, status: 'going' }] },
  { n: 3, where: null, type: 'health_camp', organiser: 'NGO', organiserName: 'City Health Volunteers (નમૂનો / sample)', titleEn: 'Free eye check-up camp (sample)', titleGu: 'મફત આંખ તપાસ કેમ્પ (નમૂનો)', placeEn: 'Town hall, Ellisbridge', placeGu: 'ટાઉન હોલ, એલિસબ્રિજ', inDays: 10, hours: 5, capacity: null, status: 'published', going: [] },
  { n: 4, where: 'vasna', type: 'other', organiser: 'Saarthee', organiserName: 'સારથી સ્વયંસેવકો / Saarthee volunteers (નમૂનો / sample)', titleEn: 'Ward walk with neighbours (sample)', titleGu: 'પડોશીઓ સાથે વોર્ડમાં પદયાત્રા (નમૂનો)', placeEn: 'Vasna bus stand', placeGu: 'વાસણા બસ સ્ટેન્ડ', inDays: 6, hours: 1, capacity: 30, status: 'cancelled', going: [] },
  { n: 5, where: 'naranpura', type: 'cleanup', organiser: 'RWA', organiserName: 'Naranpura Society Forum (નમૂનો / sample)', titleEn: 'Garden clean-up (sample, past)', titleGu: 'બગીચા સફાઈ (નમૂનો, પૂર્ણ)', placeEn: 'Municipal garden, Naranpura', placeGu: 'મ્યુનિસિપલ બગીચો, નારણપુરા', inDays: -10, hours: 2, capacity: 25, status: 'completed', going: [{ nn: 21, status: 'attended' }] },
  { n: 6, where: 'navaVadaj', type: 'tree_drive', organiser: 'NGO', organiserName: 'Green Vadaj (નમૂનો / sample)', titleEn: 'Riverside saplings (sample, draft)', titleGu: 'નદીકાંઠે રોપા વાવેતર (નમૂનો, મુસદ્દો)', placeEn: 'Nava Vadaj riverside', placeGu: 'નવા વાડજ નદીકાંઠો', inDays: 20, hours: 2, capacity: null, status: 'draft', going: [] },
];

async function wardAt(prisma: PrismaClient, where: Where): Promise<string | null> {
  if (!where) return null;
  const p = PILOT_POINTS[where];
  const rows = await prisma.$queryRaw<{ id: string }[]>`
    SELECT id FROM wards WHERE ST_Contains(geom, ST_SetSRID(ST_MakePoint(${p.lng}, ${p.lat}), 4326)) LIMIT 1`;
  return rows[0]?.id ?? null;
}

export default defineSeedModule({
  name: 'initiatives',
  requires: ['initiatives', 'rsvps', 'wards'],
  async run({ prisma }) {
    const today = new Date();
    for (const s of SAMPLES) {
      const id = seedInitiativeId(s.n);
      if (await prisma.initiative.findUnique({ where: { id }, select: { id: true } })) continue;
      // 07:00 Asia/Kolkata (01:30 UTC) on the sample day.
      const startsAt = new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate() + s.inDays, 1, 30));
      const point = s.where ? PILOT_POINTS[s.where] : null;
      await prisma.initiative.create({
        data: {
          id,
          titleEn: s.titleEn,
          titleGu: s.titleGu,
          descriptionEn: `${s.titleEn}. Fictional sample event for development; bring water and a cap.`,
          descriptionGu: `${s.titleGu}. પરીક્ષણ માટેનું કાલ્પનિક નમૂના અભિયાન. પાણી અને ટોપી સાથે લાવજો.`,
          type: s.type,
          organiser: s.organiser,
          organiserName: s.organiserName,
          wardId: await wardAt(prisma, s.where),
          locationTextEn: s.placeEn,
          locationTextGu: s.placeGu,
          lat: point?.lat ?? null,
          lng: point?.lng ?? null,
          startsAt,
          endsAt: new Date(startsAt.getTime() + s.hours * 3_600_000),
          capacity: s.capacity,
          status: s.status,
          goingCount: s.going.filter((g) => g.status === 'going').length,
          reminderSentAt: s.inDays < 0 ? startsAt : null,
        },
      });
      for (const g of s.going) {
        await prisma.rsvp.create({ data: { initiativeId: id, userId: seedUserId(g.nn), status: g.status } });
      }
    }
  },
});
