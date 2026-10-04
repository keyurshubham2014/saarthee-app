/**
 * GET /issues/{id}/events (V2 TASK-06 §5.3, AC-10): the status timeline, oldest first, cursor paged.
 * Privacy: citizens are only "A resident of <ward>"; representatives appear by role + public name;
 * moderators/admins as "Saarthee moderator"; system as "Saarthee". No user ids, phones or citizen names.
 */
import type { IssueEvent } from '@prisma/client';
import { prisma } from '../../lib/db';
import { AppError } from '../../lib/errors';
import type { AuthenticatedUser } from '../../middleware/requireUser';

export interface ActorLabel {
  kind: 'resident' | 'representative' | 'moderator' | 'system';
  wardNameEn: string | null;
  wardNameGu: string | null;
  /** Representatives only. */
  name?: { en: string; gu: string };
  repRole?: string;
}

/** Only these meta keys ever leave the server. */
const META_KEYS = ['answer', 'distanceM', 'level'] as const;

function cleanMeta(meta: unknown): Record<string, unknown> {
  if (!meta || typeof meta !== 'object') return {};
  const src = meta as Record<string, unknown>;
  return Object.fromEntries(META_KEYS.filter((k) => src[k] !== undefined).map((k) => [k, src[k]]));
}

export async function listEvents(issueId: string, viewer: AuthenticatedUser | undefined, cursor: string | undefined, limit: number) {
  const issue = await prisma.issue.findUnique({
    where: { id: issueId },
    select: { visibility: true, reporterId: true, ward: { select: { nameEn: true, nameGu: true } } },
  });
  const staff = viewer && viewer.role !== 'citizen';
  if (!issue || (issue.visibility === 'hidden' && !staff && issue.reporterId !== viewer?.id)) throw new AppError('NOT_FOUND');

  let after: { createdAt: Date; id: string } | null = null;
  if (cursor) {
    after = await prisma.issueEvent.findFirst({ where: { id: cursor, issueId }, select: { createdAt: true, id: true } });
    if (!after) throw new AppError('VALIDATION_FAILED', { details: [{ field: 'cursor', issue: 'Unknown cursor.' }] });
  }
  const rows: IssueEvent[] = await prisma.issueEvent.findMany({
    where: {
      issueId,
      ...(after ? { OR: [{ createdAt: { gt: after.createdAt } }, { createdAt: after.createdAt, id: { gt: after.id } }] } : {}),
    },
    orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
    take: limit + 1,
  });
  const page = rows.slice(0, limit);
  const repUserIds = [...new Set(page.filter((e) => e.actorRole === 'representative' && e.actorId).map((e) => e.actorId!))];
  const reps = repUserIds.length
    ? await prisma.representative.findMany({ where: { userId: { in: repUserIds } }, select: { userId: true, nameEn: true, nameGu: true, role: true } })
    : [];
  const ward = { wardNameEn: issue.ward?.nameEn ?? null, wardNameGu: issue.ward?.nameGu ?? null };

  const label = (e: IssueEvent): ActorLabel => {
    if (e.actorRole === 'system') return { kind: 'system', ...ward };
    if (e.actorRole === 'moderator' || e.actorRole === 'admin') return { kind: 'moderator', ...ward };
    if (e.actorRole === 'representative') {
      const r = reps.find((x) => x.userId === e.actorId);
      return r ? { kind: 'representative', ...ward, name: { en: r.nameEn, gu: r.nameGu }, repRole: r.role } : { kind: 'representative', ...ward };
    }
    return { kind: 'resident', ...ward };
  };

  return {
    items: page.map((e) => ({
      id: e.id, type: e.type, fromStatus: e.fromStatus, toStatus: e.toStatus, actorLabel: label(e),
      // Staff notes are shown; citizen notes (verification comments) stay private to staff.
      note: e.actorRole === 'citizen' && e.type !== 'status_change' && !staff ? null : e.note,
      photoUrls: e.photoId ? [`/api/v1/media/photos/${e.photoId}?w=1024`] : [],
      meta: cleanMeta(e.meta), createdAt: e.createdAt,
    })),
    nextCursor: rows.length > limit ? page[page.length - 1]!.id : null,
  };
}
