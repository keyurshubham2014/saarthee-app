/**
 * Staff console status changes (TASK-10), integrated with TASK-06 (W-INT10): every status write goes through
 * the lifecycle's `transitionInTx()` — the single writer of `issues.status` — inside the caller's transaction,
 * so moderation side effects (flags actioned, stamps, merges) commit atomically with the status change. The
 * caller runs the returned `afterCommit()` once the transaction commits (follower notifications).
 *
 * Rules come from TASK-06's table (`modules/lifecycle/transitions.ts`); staff rows (moderator/admin):
 *   reported, sent, reopened                        → acknowledged
 *   reported, sent, acknowledged, reopened          → in_progress
 *   reported, sent, acknowledged, in_progress, reopened → marked_fixed (optional after photos, ≤ 3)
 *   any open, marked_fixed                          → rejected (note required) / merged (moderation.service)
 */
import type { IssueStatus, Prisma } from '@prisma/client';
import { prisma } from '../../lib/db';
import { AppError } from '../../lib/errors';
import { transitionInTx, type TransitionActor, type TransitionResult } from '../lifecycle/lifecycle.service';
import { checkTransition } from '../lifecycle/transitions';

export type StaffStatusTarget = 'acknowledged' | 'in_progress' | 'marked_fixed';

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

/** TASK-10 staff identity → TASK-06 actor. A v1 email admin has no users row: userId null, kind admin. */
export function transitionActor(actor: StatusActor): TransitionActor {
  return { userId: actor.actorId, kind: actor.actorRole };
}

/**
 * Thin wrapper over `transitionInTx()` for staff actors: records a v1 email admin as `meta.adminUserId` on the
 * issue_events row (actor_id stays null). Does not write `issues.status` itself.
 */
export function transitionAsStaff(
  tx: Prisma.TransactionClient,
  issueId: string,
  to: IssueStatus,
  actor: StatusActor,
  opts: { note?: string | null; photoIds?: string[]; notifyExcept?: string[]; mergedIntoId?: string } = {},
): Promise<TransitionResult> {
  return transitionInTx(tx, issueId, to, transitionActor(actor), {
    ...opts,
    ...(actor.actorId ? {} : { meta: { adminUserId: actor.handlerId } }),
  });
}

/**
 * Acknowledge / in progress / mark fixed from the staff console. `expectedStatus` guards against another
 * moderator having changed it (409 ISSUE_STATE_INVALID). After photos must be the actor's own unattached
 * `purpose='after'` uploads from the last 24 h (TASK-06 rule); they are attached as `issue_photos.kind = 'after'`.
 */
export async function staffTransition(
  issueId: string,
  to: StaffStatusTarget,
  actor: StatusActor,
  opts: { note?: string; photoIds?: string[]; expectedStatus?: IssueStatus },
) {
  const photoIds = opts.photoIds ?? [];
  const result = await prisma.$transaction(async (tx) => {
    const issue = await lockIssue(tx, issueId);
    // TASK-10 error contract, checked before transition() so its codes win over STALE_STATUS / VALIDATION_FAILED.
    if (opts.expectedStatus && opts.expectedStatus !== issue.status) throw new AppError('ISSUE_STATE_INVALID');
    const check = checkTransition(issue.status, to, transitionActor(actor).kind);
    if (!check.ok) throw new AppError(check.code);
    if (photoIds.length > 0 && (to !== 'marked_fixed' || !actor.actorId)) throw new AppError('PHOTO_UNUSABLE');
    return transitionAsStaff(tx, issueId, to, actor, { note: opts.note ?? null, photoIds });
  });
  await result.afterCommit();
  return result;
}
