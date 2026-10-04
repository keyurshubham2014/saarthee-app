/**
 * GET /issues/{id}/lifecycle (V2 TASK-06): what the app's lifecycle widgets need — derived status fields,
 * names, location (for the live verify distance), before/after photo URLs and the viewer's allowed actions
 * (role-aware `IssueStatusActions`). TASK-07's detail endpoint may embed the same `viewer` block.
 */
import type { IssueStatus } from '@prisma/client';
import { config } from '../../config';
import { now as clockNow } from '../../lib/clock';
import { prisma } from '../../lib/db';
import { AppError } from '../../lib/errors';
import type { AuthenticatedUser } from '../../middleware/requireUser';
import { serializeIssue } from '../issues/derive';
import { istDay } from './verification.service';
import { actorFor, representativeWardIds } from './lifecycle.service';
import { checkTransition, OPEN_STATUSES } from './transitions';

const photoUrl = (id: string | undefined) => (id ? `/api/v1/media/photos/${id}?w=1024` : null);

export async function readLifecycle(issueId: string, viewer: AuthenticatedUser | undefined) {
  const issue = await prisma.issue.findUnique({
    where: { id: issueId },
    include: {
      category: { select: { slug: true, nameEn: true, nameGu: true, slaDays: true } },
      ward: { select: { nameEn: true, nameGu: true } },
      photos: { orderBy: { position: 'asc' }, select: { photoId: true, kind: true } },
    },
  });
  const staff = viewer && viewer.role !== 'citizen';
  if (!issue || (issue.visibility === 'hidden' && !staff && issue.reporterId !== viewer?.id)) throw new AppError('NOT_FOUND');

  const base = serializeIssue(issue);
  let can = { acknowledge: false, start: false, markFixed: false, reject: false, verify: false, escalate: false, ccrsClosed: false };
  let isReporter = false;
  let isFollower = false;
  let answeredToday = false;
  if (viewer) {
    isReporter = issue.reporterId === viewer.id;
    isFollower = isReporter || (await prisma.follow.count({ where: { issueId, userId: viewer.id } })) > 0;
    const actor = actorFor(viewer, issue);
    const wards = actor.kind === 'representative' ? await representativeWardIds(viewer.id) : [];
    const allowed = (to: IssueStatus) => {
      const c = checkTransition(issue.status, to, actor.kind);
      if (!c.ok) return false;
      if (actor.kind === 'representative' && c.rule.wardScoped && !(issue.wardId && wards.includes(issue.wardId))) return false;
      return !(actor.kind === 'reporter' && c.rule.reporterNeedsCcrs && !issue.ccrsNumber);
    };
    answeredToday = (await prisma.issueVerification.count({ where: { issueId, userId: viewer.id, createdDay: istDay(clockNow()) } })) > 0;
    const windowOpen = base.verifyWindowClosesAt !== null && clockNow().getTime() <= base.verifyWindowClosesAt.getTime();
    can = {
      acknowledge: allowed('acknowledged'),
      start: allowed('in_progress'),
      markFixed: allowed('marked_fixed'),
      reject: allowed('rejected'),
      verify: windowOpen && !answeredToday,
      escalate: isFollower && viewer.role === 'citizen' && OPEN_STATUSES.includes(issue.status),
      ccrsClosed: isReporter && issue.ccrsNumber !== null && issue.ccrsClosedAt === null,
    };
  }
  const first = (kind: string) => issue.photos.find((p) => p.kind === kind)?.photoId;
  return {
    issue: {
      ...base,
      categorySlug: issue.category.slug, categoryNameEn: issue.category.nameEn, categoryNameGu: issue.category.nameGu, slaDays: issue.category.slaDays,
      wardNameEn: issue.ward?.nameEn ?? null, wardNameGu: issue.ward?.nameGu ?? null,
      latitude: Number(issue.lat), longitude: Number(issue.lng), createdAt: issue.createdAt,
      reportPhotoUrl: photoUrl(first('report')), afterPhotoUrl: photoUrl(first('after')),
      ccrsFiledAt: issue.ccrsFiledAt,
      ccrsReopenDeadline: issue.ccrsClosedAt ? new Date(issue.ccrsClosedAt.getTime() + config.CCRS_REOPEN_HOURS * 3_600_000) : null,
      verifyRadiusM: config.VERIFY_RADIUS_M, verifyMaxAccuracyM: config.VERIFY_MAX_ACCURACY_M,
    },
    viewer: { signedIn: viewer !== undefined, isReporter, isFollower, answeredToday, can },
  };
}
