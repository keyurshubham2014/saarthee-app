import { defineSeedModule } from '../types';
import { seedUserId } from './040-citizens';

/**
 * V2 TASK-11 dev seed (fictional only): "Sample Representative Demo" (rep.demo, +919000000027, Auth Emulator
 * uid seed-uid-27) verified for Sample Corporator 18-A (Navrangpura) with an approved claim; one pending claim
 * (Sample Corporator 31-B, by Sample Citizen Asha), one rejected claim (Sample Corporator 9-B, by Sample Citizen
 * Bhavin), one expired verification on a previous-term record, and 6 relayed messages to 18-A (2 replied by
 * email, 1 in-app). Ward 30 (Paldi) records are left unclaimed for the M-11-01 walkthrough. Idempotent.
 */
const rid = (group: number, n: number) => `00000009-${String(group).padStart(4, '0')}-4000-8000-${String(n).padStart(12, '0')}`;
const cid = (n: number) => `00000011-0000-4000-8000-${String(n).padStart(12, '0')}`;
const mid = (n: number) => `00000011-0001-4000-8000-${String(n).padStart(12, '0')}`;
const DAY = 86_400_000;
const ago = (d: number) => new Date(Date.now() - d * DAY);

export default defineSeedModule({
  name: 'rep-claims',
  requires: ['rep_claims', 'rep_messages', 'representatives', 'users'],
  async run({ prisma, log }) {
    const demo = seedUserId(27);
    const corp18 = rid(18, 1);
    if (!(await prisma.representative.findUnique({ where: { id: corp18 }, select: { id: true } }))) {
      log('Seed rep-claims: skipped (TASK-09 sample representatives missing)');
      return;
    }
    if (!(await prisma.user.findUnique({ where: { id: demo }, select: { id: true } }))) {
      await prisma.user.create({
        data: {
          id: demo, phoneE164: '+919000000027', firebaseUid: 'seed-uid-27', displayName: 'Sample Representative Demo', language: 'en', role: 'representative',
          consents: { create: [{ purpose: 'core_service', textVersion: 'v2' }] },
        },
      });
    }
    const rep = await prisma.representative.findUniqueOrThrow({ where: { id: corp18 } });
    if (!rep.userId) {
      await prisma.representative.update({ where: { id: corp18 }, data: { userId: demo, verifiedAt: new Date('2026-10-03T05:30:00Z'), verifiedMethod: 'certificate_of_election' } });
    }
    const claim = async (n: number, data: Parameters<typeof prisma.repClaim.create>[0]['data']) => {
      if (!(await prisma.repClaim.findUnique({ where: { id: cid(n) }, select: { id: true } }))) await prisma.repClaim.create({ data: { id: cid(n), ...data } });
    };
    await claim(1, { representativeId: corp18, userId: demo, status: 'approved', otpVerified: true, phoneMatch: false, verifiedMethod: 'certificate_of_election', termEnd: rep.termEnd, decidedAt: new Date('2026-10-03T05:30:00Z') });
    await claim(2, { representativeId: rid(31, 2), userId: seedUserId(21), status: 'pending', otpVerified: true, phoneMatch: false, claimantNote: 'Sample pending claim' });
    await claim(3, { representativeId: rid(9, 2), userId: seedUserId(22), status: 'rejected', otpVerified: true, rejectReason: 'Document unreadable', decidedAt: ago(5) });

    // Previous-term record whose verification ended with the term (badge: "Verification ended with the term").
    const former = rid(911, 1);
    const ward31 = await prisma.ward.findFirst({ where: { number: 31 }, select: { id: true } });
    if (ward31 && !(await prisma.representative.findUnique({ where: { id: former }, select: { id: true } }))) {
      await prisma.representative.create({
        data: {
          id: former, nameEn: 'Sample Corporator 31-Former', nameGu: 'નમૂના પૂર્વ કોર્પોરેટર 31', role: 'corporator', partyText: 'Independent',
          termStart: new Date('2021-03-01T00:00:00Z'), termEnd: new Date('2026-02-28T00:00:00Z'), sourceUrl: 'https://example.org/saarthee-sample-roster',
          lastVerifiedAt: new Date('2026-09-12T00:00:00Z'), isActive: true, areas: { create: [{ wardId: ward31.id }] },
        },
      });
    }
    if (ward31) await claim(4, { representativeId: former, userId: seedUserId(23), status: 'expired', otpVerified: true, verifiedMethod: 'official_gazette', termEnd: new Date('2026-02-28T00:00:00Z'), decidedAt: new Date('2026-03-01T00:00:00Z') });

    const msgs = [
      { n: 1, from: 21, subject: 'Streetlight out near the school', share: true },
      { n: 2, from: 22, subject: 'Garbage not collected for 3 days', share: false, reply: 'email' as const },
      { n: 3, from: 23, subject: 'Pothole on the main road', share: false, reply: 'email' as const },
      { n: 4, from: 24, subject: 'Drain overflowing after rain', share: false, reply: 'in_app' as const },
      { n: 5, from: 21, subject: 'Tree branch hanging low', share: false },
      { n: 6, from: 22, subject: 'Water leakage from pipeline', share: false },
    ];
    for (const m of msgs) {
      if (await prisma.repMessage.findUnique({ where: { id: mid(m.n) }, select: { id: true } })) continue;
      const sentAt = ago(10 - m.n);
      await prisma.repMessage.create({
        data: {
          id: mid(m.n), clientMessageId: mid(100 + m.n), representativeId: corp18, citizenId: seedUserId(m.from), subject: m.subject,
          body: `Sample message: ${m.subject.toLowerCase()}. Please help get this fixed.`, sharePhone: m.share, status: m.reply ? 'replied' : 'sent',
          attempts: 1, sentAt, createdAt: sentAt, replyToken: `5eed11${String(m.n).padStart(26, '0')}`,
          ...(m.reply ? { repliedAt: new Date(sentAt.getTime() + DAY), replyChannel: m.reply, replyBody: 'Sample reply: we have raised this with AMC.', readByRepAt: sentAt } : {}),
        },
      });
    }
    log('Seed rep-claims: rep.demo verified for Sample Corporator 18-A; claims approved/pending/rejected/expired; 6 relayed messages');
  },
});
