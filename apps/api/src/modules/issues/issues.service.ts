/**
 * POST /issues (V2 TASK-05 §5.3 workflow, REQ-F-016): idempotent by clientSubmissionId; ward/zone from
 * resolveWard(); SLA due date from the category; issue + photos + opening event + reporter follow in one
 * transaction.
 */
import { Prisma, type Issue } from '@prisma/client';
import { config } from '../../config';
import { prisma } from '../../lib/db';
import { AppError, type ErrorDetail } from '../../lib/errors';
import { logger } from '../../lib/logger';
import { assertDailyQuota } from '../../lib/quota';
import type { AuthenticatedUser } from '../../middleware/requireUser';
import { amcProblemTypesFor, type AmcProblemTypeDto } from '../categories';
import { resolveWard } from '../geo/geo.service';
import { STRUCTURED_REASONS, type CreateIssueBody } from './issues.schemas';

const DAY_MS = 86_400_000;
const PHOTO_MAX_AGE_MS = DAY_MS;
const CLOCK_SKEW_MS = 10 * 60_000;

export interface CreateIssueResult {
  created: boolean;
  body: {
    issue: { id: string; status: string; wardId: string | null; wardNameEn: string | null; wardNameGu: string | null; slaDueAt: Date; createdAt: Date; visibility: string };
    amcHandoff: { problemTypes: AmcProblemTypeDto[] };
  };
}

/** Tests only (T-05-16): runs inside the transaction right after the issue insert. */
export const createIssueHooks: { afterInsert?: () => Promise<void> } = {};

const invalid = (field: string, issue: string) => new AppError('VALIDATION_FAILED', { details: [{ field, issue }] });

function metres(aLat: number, aLng: number, bLat: number, bLng: number): number {
  const r = (d: number) => (d * Math.PI) / 180;
  const h = Math.sin(r(bLat - aLat) / 2) ** 2 + Math.cos(r(aLat)) * Math.cos(r(bLat)) * Math.sin(r(bLng - aLng) / 2) ** 2;
  return Math.round(2 * 6_371_008.8 * Math.asin(Math.sqrt(h)));
}

async function respond(issue: Issue, created: boolean): Promise<CreateIssueResult> {
  const ward = issue.wardId ? await prisma.ward.findUnique({ where: { id: issue.wardId }, select: { nameEn: true, nameGu: true } }) : null;
  return {
    created,
    body: {
      issue: {
        id: issue.id, status: issue.status, wardId: issue.wardId, wardNameEn: ward?.nameEn ?? null, wardNameGu: ward?.nameGu ?? null,
        slaDueAt: issue.slaDueAt, createdAt: issue.createdAt, visibility: issue.visibility,
      },
      amcHandoff: { problemTypes: await amcProblemTypesFor(issue.categoryId) },
    },
  };
}

async function existing(clientSubmissionId: string, userId: string): Promise<CreateIssueResult | null> {
  const prev = await prisma.issue.findUnique({ where: { clientSubmissionId } });
  if (!prev) return null;
  if (prev.reporterId !== userId) throw new AppError('IDEMPOTENCY_KEY_REUSED');
  return respond(prev, false);
}

type Opts = { res?: import('express').Response };

export async function createIssue(user: AuthenticatedUser, b: CreateIssueBody, opts: Opts = {}): Promise<CreateIssueResult> {
  const repeat = await existing(b.clientSubmissionId, user.id);
  if (repeat) return repeat;
  try {
    return await createNew(user, b, opts);
  } catch (err) {
    // A concurrent retry with the same key may have committed meanwhile (its photos are now attached, so this
    // attempt fails a business rule): the client must still get 200 with that issue.
    const again = await existing(b.clientSubmissionId, user.id);
    if (again) return again;
    if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') throw new AppError('PHOTO_UNUSABLE');
    throw err;
  }
}

async function createNew(user: AuthenticatedUser, b: CreateIssueBody, opts: Opts): Promise<CreateIssueResult> {

  const photoIds = [...new Set(b.photoIds)];
  if (photoIds.length !== b.photoIds.length) throw invalid('photoIds', 'Each photo can be added once.');
  if (photoIds.length > config.ISSUE_MAX_PHOTOS) throw invalid('photoIds', `Add at most ${config.ISSUE_MAX_PHOTOS} photos.`);
  if (Date.parse(b.deviceCapturedAt) > Date.now() + CLOCK_SKEW_MS) throw invalid('deviceCapturedAt', 'Check the date and time on your phone.');

  await assertDailyQuota(user.id, 'issues', { res: opts.res });

  const category = await prisma.category.findUnique({ where: { slug: b.categorySlug } });
  if (!category || !category.isActive) throw new AppError('CATEGORY_INACTIVE');

  let description = b.description;
  if (category.sensitive) {
    if (description) throw invalid('description', 'Choose one of the options instead of writing a description.');
    const label = b.structuredReason ? STRUCTURED_REASONS[category.slug]?.[b.structuredReason] : undefined;
    if (!label) throw invalid('structuredReason', 'Choose one of the options.');
    description = label;
  }

  const photos = await prisma.photo.findMany({
    where: {
      id: { in: photoIds }, purpose: 'report', uploadedByUserId: user.id, attachedAt: null, deletedAt: null,
      uploadedAt: { gt: new Date(Date.now() - PHOTO_MAX_AGE_MS) },
    },
    select: { id: true },
  });
  if (photos.length !== photoIds.length) throw new AppError('PHOTO_UNUSABLE');

  const located = await resolveWard(b.latitude, b.longitude);
  if (!located) {
    throw new AppError('OUTSIDE_SERVICE_AREA', { message: "This place is outside Ahmedabad's wards. Saarthee can only take reports inside the city." });
  }
  if (located.confirm && b.confirmedWardId !== located.ward.id) {
    const detail = { field: 'confirmedWardId', issue: 'Confirm the suggested ward.', suggestedWardId: located.ward.id };
    throw new AppError('WARD_CONFIRMATION_REQUIRED', { details: [detail as ErrorDetail] });
  }

  const now = new Date();
  const note = b.pinAdjusted
    ? `pinAdjusted${b.fixLatitude !== undefined && b.fixLongitude !== undefined ? `; pinDistanceFromFixM=${metres(b.fixLatitude, b.fixLongitude, b.latitude, b.longitude)}` : ''}`
    : null;
  const issue = await prisma.$transaction(async (tx) => {
    const row = await tx.issue.create({
      data: {
        clientSubmissionId: b.clientSubmissionId, reporterId: user.id, categoryId: category.id,
        title: `${category.nameEn} · ${located.ward.nameEn}`.slice(0, 120), description,
        lat: b.latitude, lng: b.longitude, gpsAccuracyM: b.gpsAccuracyM ?? null,
        wardId: located.ward.id, zoneId: located.zone.id, status: 'reported', statusChangedAt: now,
        slaDueAt: new Date(now.getTime() + category.slaDays * DAY_MS), meTooCount: 0, followerCount: 1,
        visibility: category.sensitive ? 'hidden' : 'public', isSensitive: category.sensitive,
      },
    });
    await createIssueHooks.afterInsert?.();
    await tx.issuePhoto.createMany({ data: photoIds.map((photoId, position) => ({ issueId: row.id, photoId, kind: 'report' as const, position })) });
    const attached = await tx.photo.updateMany({ where: { id: { in: photoIds }, attachedAt: null }, data: { attachedAt: now } });
    if (attached.count !== photoIds.length) throw new AppError('PHOTO_UNUSABLE');
    await tx.issueEvent.create({
      data: { issueId: row.id, actorId: user.id, actorRole: 'citizen', type: 'status_change', fromStatus: null, toStatus: 'reported', note },
    });
    await tx.follow.create({ data: { issueId: row.id, userId: user.id } });
    return row;
  });
  // Analytics: the v1 events table only accepts v1 names (ck_events_name), so this is a structured log line.
  logger.info({ event: 'issue_submitted', categorySlug: category.slug, wardNumber: located.ward.number, photoCount: photoIds.length, pinAdjusted: b.pinAdjusted }, 'issue submitted');
  return respond(issue, true);
}
