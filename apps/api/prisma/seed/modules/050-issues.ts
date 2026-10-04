import type { ActorRole, IssueEventType, IssueStatus, IssueVisibility, Prisma } from '@prisma/client';
import { makePlaceholderJpeg } from '../seed-photo';
import { daysAgo, defineSeedModule } from '../types';
import { seedUserId } from './040-citizens';

export const seedIssueId = (nn: number) => `5eed0002-0000-4000-8000-0000000000${String(nn).padStart(2, '0')}`;

/** Points inside the 5 launch wards (Spec D5); checked against the ward polygons by TASK-02's seed test. */
export const PILOT_POINTS = {
  paldi: { lat: 23.0105, lng: 72.5605 },
  navrangpura: { lat: 23.0368, lng: 72.5580 },
  vasna: { lat: 22.9965, lng: 72.5480 },
  naranpura: { lat: 23.0560, lng: 72.5530 },
  navaVadaj: { lat: 23.0693, lng: 72.5626 },
} as const;

type Step = { to: IssueStatus; actor: number; role: ActorRole; type?: IssueEventType; note?: string };

interface IssueSpec {
  nn: number;
  status: IssueStatus;
  category: string;
  title: string;
  where: keyof typeof PILOT_POINTS;
  /** metres-ish offset so points in one ward differ */
  offset: number;
  reporter: number;
  createdDaysAgo: number;
  path: Step[];
  visibility?: IssueVisibility;
  sensitive?: boolean;
  mergedInto?: number;
  ccrs?: string;
  afterPhoto?: boolean;
  verification?: { user: number; answer: 'fixed' | 'not_fixed'; daysAgo: number };
  meToos?: number[];
  follows?: number[];
}

const MOD = 25; // Sample Moderator Esha

/**
 * Sample issues (V2 TASK-01 §5.2): at least one public issue per status (the merged one points at its
 * canonical issue), exactly one overdue open issue, one hidden and one sensitive. Counts are listed in
 * prisma/SEED-EXPECTATIONS.md (v2 section).
 */
export const ISSUE_SPECS: readonly IssueSpec[] = [
  { nn: 1, status: 'reported', category: 'roads', title: 'Deep pothole near the bus stop', where: 'paldi', offset: 0, reporter: 21, createdDaysAgo: 2,
    path: [{ to: 'reported', actor: 21, role: 'citizen' }], meToos: [22, 23, 24], follows: [21, 25] },
  { nn: 2, status: 'sent', category: 'garbage', title: 'Garbage not collected for a week', where: 'navrangpura', offset: 0, reporter: 22, createdDaysAgo: 3, ccrs: 'SAMPLE-CCRS-0002',
    path: [{ to: 'reported', actor: 22, role: 'citizen' }, { to: 'sent', actor: 22, role: 'citizen' }], meToos: [21], follows: [22] },
  { nn: 3, status: 'acknowledged', category: 'streetlight', title: 'Streetlight off on the main road', where: 'vasna', offset: 0, reporter: 23, createdDaysAgo: 4,
    path: [{ to: 'reported', actor: 23, role: 'citizen' }, { to: 'sent', actor: 23, role: 'citizen' }, { to: 'acknowledged', actor: MOD, role: 'moderator' }] },
  { nn: 4, status: 'in_progress', category: 'drainage', title: 'Overflowing drain', where: 'naranpura', offset: 0, reporter: 24, createdDaysAgo: 5,
    path: [{ to: 'reported', actor: 24, role: 'citizen' }, { to: 'acknowledged', actor: MOD, role: 'moderator' }, { to: 'in_progress', actor: MOD, role: 'moderator' }] },
  { nn: 5, status: 'marked_fixed', category: 'water', title: 'Leaking water pipe', where: 'navaVadaj', offset: 0, reporter: 21, createdDaysAgo: 6, afterPhoto: true,
    path: [{ to: 'reported', actor: 21, role: 'citizen' }, { to: 'acknowledged', actor: MOD, role: 'moderator' }, { to: 'in_progress', actor: MOD, role: 'moderator' }, { to: 'marked_fixed', actor: MOD, role: 'moderator' }] },
  { nn: 6, status: 'verified', category: 'trees', title: 'Fallen tree branch on footpath', where: 'paldi', offset: 1, reporter: 22, createdDaysAgo: 20,
    verification: { user: 23, answer: 'fixed', daysAgo: 12 }, follows: [22],
    path: [{ to: 'reported', actor: 22, role: 'citizen' }, { to: 'acknowledged', actor: MOD, role: 'moderator' }, { to: 'marked_fixed', actor: 22, role: 'citizen' }, { to: 'verified', actor: 23, role: 'citizen' }] },
  { nn: 7, status: 'reopened', category: 'animals', title: 'Stray cattle blocking the lane', where: 'navrangpura', offset: 1, reporter: 23, createdDaysAgo: 6,
    verification: { user: 24, answer: 'not_fixed', daysAgo: 1 },
    path: [{ to: 'reported', actor: 23, role: 'citizen' }, { to: 'marked_fixed', actor: MOD, role: 'moderator' }, { to: 'reopened', actor: 24, role: 'citizen' }] },
  { nn: 8, status: 'rejected', category: 'other', title: 'Test report', where: 'vasna', offset: 1, reporter: 24, createdDaysAgo: 3,
    path: [{ to: 'reported', actor: 24, role: 'citizen' }, { to: 'rejected', actor: MOD, role: 'moderator', type: 'rejected', note: 'Not a civic issue (sample).' }] },
  { nn: 9, status: 'merged', category: 'roads', title: 'Pothole at the bus stop', where: 'paldi', offset: 2, reporter: 23, createdDaysAgo: 1, mergedInto: 1,
    path: [{ to: 'reported', actor: 23, role: 'citizen' }, { to: 'merged', actor: MOD, role: 'moderator', type: 'merged', note: 'Duplicate of an earlier report.' }] },
  { nn: 10, status: 'acknowledged', category: 'garbage', title: 'Open garbage dump behind the market', where: 'naranpura', offset: 1, reporter: 21, createdDaysAgo: 20,
    path: [{ to: 'reported', actor: 21, role: 'citizen' }, { to: 'acknowledged', actor: MOD, role: 'moderator' }] },
  { nn: 11, status: 'reported', category: 'encroachment', title: 'Footpath blocked by stalls', where: 'navaVadaj', offset: 1, reporter: 22, createdDaysAgo: 1, visibility: 'hidden',
    path: [{ to: 'reported', actor: 22, role: 'citizen' }] },
  { nn: 12, status: 'reported', category: 'building', title: 'Unsafe construction site', where: 'paldi', offset: 3, reporter: 24, createdDaysAgo: 2, sensitive: true,
    path: [{ to: 'reported', actor: 24, role: 'citizen' }] },
];

const istDay = (d: Date) => new Date(`${new Date(d.getTime() + 330 * 60_000).toISOString().slice(0, 10)}T00:00:00Z`);

export default defineSeedModule({
  name: 'issues',
  requires: ['issues', 'issue_photos', 'issue_events', 'issue_verifications', 'me_toos', 'follows', 'users', 'categories'],
  async run({ prisma, photoDir }) {
    const cats = new Map((await prisma.category.findMany({ select: { id: true, slug: true, slaDays: true } })).map((c) => [c.slug, c]));
    let hue = 100;
    for (const s of ISSUE_SPECS) {
      const id = seedIssueId(s.nn);
      if (await prisma.issue.findUnique({ where: { id }, select: { id: true } })) continue;
      const cat = cats.get(s.category);
      if (!cat) throw new Error(`category ${s.category} missing (run categories-dev first)`);
      const p = PILOT_POINTS[s.where];
      const lat = Number((p.lat + s.offset * 0.0004).toFixed(6));
      const lng = Number((p.lng + s.offset * 0.0003).toFixed(6));
      const created = daysAgo(s.createdDaysAgo);
      const now = Date.now();
      const span = now - created.getTime();
      // Steps spread evenly from creation to (now - 1h); the verification step sits at its own time.
      const at = (i: number) => (i === 0 ? created : new Date(created.getTime() + ((span - 3_600_000) * i) / s.path.length));
      const verifyAt = s.verification ? daysAgo(s.verification.daysAgo) : null;
      const times = s.path.map((step, i) =>
        verifyAt && (step.to === 'verified' || step.to === 'reopened') ? verifyAt : at(i),
      );

      // v1's ck_photos_verification_complaint ties purpose 'verification' to a v1 complaint, so v2 sample
      // photos all use purpose 'report'; the issue_photos.kind says what they are (TASK-06 revisits purposes).
      const photoRow = async (when: Date) => {
        const img = await makePlaceholderJpeg(photoDir, hue++);
        return prisma.photo.create({
          data: {
            storageKey: img.key, purpose: 'report', mimeType: 'image/jpeg', byteSize: img.byteSize, widthPx: img.width,
            heightPx: img.height, sha256: img.sha256, uploadedAt: when, attachedAt: when,
          },
          select: { id: true },
        });
      };
      const report = await photoRow(created);
      const after = s.afterPhoto ? await photoRow(times[times.length - 1]!) : null;
      const verifyPhoto = verifyAt ? await photoRow(verifyAt) : null;

      const photos: Prisma.IssuePhotoCreateManyInput[] = [{ issueId: id, photoId: report.id, kind: 'report', position: 0 }];
      if (after) photos.push({ issueId: id, photoId: after.id, kind: 'after', position: 0 });
      if (verifyPhoto) photos.push({ issueId: id, photoId: verifyPhoto.id, kind: 'verification', position: 0 });

      await prisma.$transaction(async (tx) => {
        await tx.issue.create({
          data: {
            id,
            clientSubmissionId: `5eed0003-0000-4000-8000-0000000000${String(s.nn).padStart(2, '0')}`,
            reporterId: seedUserId(s.reporter),
            categoryId: cat.id,
            title: s.title,
            description: 'Sample issue created by the development seed.',
            lat,
            lng,
            gpsAccuracyM: 6,
            status: s.status,
            statusChangedAt: times[times.length - 1]!,
            slaDueAt: new Date(created.getTime() + cat.slaDays * 86_400_000),
            meTooCount: s.meToos?.length ?? 0,
            followerCount: s.follows?.length ?? 0,
            ccrsNumber: s.ccrs ?? null,
            ccrsFiledAt: s.ccrs ? times[1] ?? created : null,
            visibility: s.visibility ?? 'public',
            isSensitive: s.sensitive ?? false,
            mergedIntoId: s.mergedInto ? seedIssueId(s.mergedInto) : null,
            createdAt: created,
          },
        });
        await tx.issuePhoto.createMany({ data: photos });
        await tx.issueEvent.createMany({
          data: s.path.map((step, i) => ({
            issueId: id,
            actorId: seedUserId(step.actor),
            actorRole: step.role,
            type: step.type ?? 'status_change',
            fromStatus: i === 0 ? null : s.path[i - 1]!.to,
            toStatus: step.to,
            note: step.note ?? null,
            photoId:
              step.to === 'marked_fixed' && after ? after.id : (step.to === 'verified' || step.to === 'reopened') && verifyPhoto ? verifyPhoto.id : null,
            createdAt: times[i]!,
          })),
        });
        if (s.verification && verifyAt) {
          await tx.issueVerification.create({
            data: {
              issueId: id, userId: seedUserId(s.verification.user), answer: s.verification.answer,
              photoId: verifyPhoto?.id ?? null, lat, lng, distanceM: 4, createdDay: istDay(verifyAt), createdAt: verifyAt,
            },
          });
        }
        if (s.meToos?.length) {
          await tx.meToo.createMany({ data: s.meToos.map((u) => ({ issueId: id, userId: seedUserId(u), createdAt: created })) });
        }
        if (s.follows?.length) {
          await tx.follow.createMany({ data: s.follows.map((u) => ({ issueId: id, userId: seedUserId(u), createdAt: created })) });
        }
      });
    }
  },
});
