/**
 * TASK-10 stand-in for TASK-06's lifecycle `transition()` — the ONE place the staff console writes
 * `issues.status`. INTEGRATOR: when TASK-06 (`src/modules/lifecycle`) lands, replace the body of
 * `staffTransition` (and `writeStatus`) with calls to its `transition()`; the routes and services in this
 * module call only these two functions for status changes.
 *
 * Staff rows of TASK-06's transition table (moderator/admin actors):
 *   reported, sent, reopened                        → acknowledged
 *   reported, sent, acknowledged, reopened          → in_progress
 *   reported, sent, acknowledged, in_progress, reopened → marked_fixed (optional after photos, ≤ 3)
 *   any open, marked_fixed                          → rejected / merged (moderation.service)
 */
import type { IssueStatus, Prisma } from '@prisma/client';
import { now } from '../../lib/clock';
import { prisma } from '../../lib/db';
import { AppError } from '../../lib/errors';

export type StaffStatusTarget = 'acknowledged' | 'in_progress' | 'marked_fixed';

const FROM: Record<StaffStatusTarget, IssueStatus[]> = {
  acknowledged: ['reported', 'sent', 'reopened'],
  in_progress: ['reported', 'sent', 'acknowledged', 'reopened'],
  marked_fixed: ['reported', 'sent', 'acknowledged', 'in_progress', 'reopened'],
};

/** Issue statuses a moderator may still reject or merge. */
export const TERMINAL_OPEN: IssueStatus[] = ['reported', 'sent', 'acknowledged', 'in_progress', 'reopened', 'marked_fixed'];

export interface StatusActor {
  /** users.id for issue_events.actor_id (null for a v1 admin_user actor, which has no users row). */
  actorId: string | null;
  /** Staff actor id (users.id or admin_users.id) for handled_by / hidden_by columns. */
  handlerId: string;
  actorRole: 'admin' | 'moderator' | 'representative';
}

export interface LockedIssue {
  id: string;
  status: IssueStatus;
  reporter_id: string | null;
  ward_id: string | null;
  category_id: string;
  visibility: 'public' | 'hidden';
  is_sensitive: boolean;
  created_at: Date;
  moderated_at: Date | null;
}

/** `SELECT … FOR UPDATE` on one issue; 404 when missing. */
export async function lockIssue(tx: Prisma.TransactionClient, id: string): Promise<LockedIssue> {
  const rows = await tx.$queryRaw<LockedIssue[]>`
    SELECT id, status, reporter_id, ward_id, category_id, visibility, is_sensitive, created_at, moderated_at
    FROM issues WHERE id = ${id}::uuid FOR UPDATE`;
  if (!rows[0]) throw new AppError('NOT_FOUND');
  return rows[0];
}

/** Writes the status + its issue_events row inside the caller's transaction (single status write path). */
export async function writeStatus(
  tx: Prisma.TransactionClient,
  issue: LockedIssue,
  to: IssueStatus,
  actor: StatusActor,
  opts: { note?: string | null; photoId?: string | null; mergedIntoId?: string; eventType?: 'status_change' | 'rejected' | 'merged' } = {},
) {
  const at = now();
  await tx.issue.update({
    where: { id: issue.id },
    data: { status: to, statusChangedAt: at, ...(opts.mergedIntoId ? { mergedIntoId: opts.mergedIntoId } : {}) },
  });
  return tx.issueEvent.create({
    data: {
      issueId: issue.id, actorId: actor.actorId, actorRole: actor.actorRole, type: opts.eventType ?? 'status_change',
      fromStatus: issue.status, toStatus: to, note: opts.note ?? null, photoId: opts.photoId ?? null, createdAt: at,
    },
  });
}

/**
 * Acknowledge / in progress / mark fixed from the staff console. `expectedStatus` guards against another
 * moderator having changed it (409 ISSUE_STATE_INVALID). After photos must be the actor's own unattached
 * uploads; they are attached as `issue_photos.kind = 'after'`.
 */
export async function staffTransition(
  issueId: string,
  to: StaffStatusTarget,
  actor: StatusActor,
  opts: { note?: string; photoIds?: string[]; expectedStatus?: IssueStatus },
) {
  const photoIds = opts.photoIds ?? [];
  return prisma.$transaction(async (tx) => {
    const issue = await lockIssue(tx, issueId);
    if (opts.expectedStatus && opts.expectedStatus !== issue.status) throw new AppError('ISSUE_STATE_INVALID');
    if (!FROM[to].includes(issue.status)) throw new AppError('INVALID_TRANSITION');
    if (photoIds.length > 0) {
      if (to !== 'marked_fixed' || !actor.actorId) throw new AppError('PHOTO_UNUSABLE');
      const attached = await tx.photo.updateMany({
        where: { id: { in: photoIds }, uploadedByUserId: actor.actorId, attachedAt: null, deletedAt: null },
        data: { attachedAt: now() },
      });
      if (attached.count !== photoIds.length) throw new AppError('PHOTO_UNUSABLE');
      const last = await tx.issuePhoto.aggregate({ where: { issueId, kind: 'after' }, _max: { position: true } });
      const start = (last._max.position ?? -1) + 1;
      await tx.issuePhoto.createMany({ data: photoIds.map((photoId, i) => ({ issueId, photoId, kind: 'after' as const, position: start + i })) });
    }
    const event = await writeStatus(tx, issue, to, actor, { note: opts.note ?? null, photoId: photoIds[0] ?? null });
    return { issue, event };
  });
}
