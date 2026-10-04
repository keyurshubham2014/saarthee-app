/**
 * `transition()` — the single writer of `issues.status` (V2 TASK-06 §5.3, binding contract). Row lock,
 * idempotency by clientActionId, optimistic `expectedStatus`, table + role + ward checks, timestamps, SLA
 * reset on reopen, after photos, one `issue_events` row; follower notifications only after commit.
 */
import { Prisma, type Issue, type IssueEvent, type IssueStatus, type UserRole } from '@prisma/client';
import { now as clockNow } from '../../lib/clock';
import { prisma } from '../../lib/db';
import { AppError } from '../../lib/errors';
import { notifyStatusChange } from './notify';
import { checkTransition, eventActorRole, type ActorKind } from './transitions';

type Tx = Prisma.TransactionClient;
const DAY_MS = 86_400_000;
const AFTER_PHOTO_MAX = 3;

export interface TransitionActor {
  /**
   * null for `system`, and for a v1 email admin (an `admin_users` row with no `users` row, kind `admin`):
   * the caller then records who acted as `meta.adminUserId` (integration W-INT10). Such an actor cannot
   * attach photos (PHOTO_UNUSABLE) because photos are owned by a users row.
   */
  userId: string | null;
  kind: ActorKind;
}

export interface TransitionOptions {
  note?: string | null;
  photoIds?: string[];
  clientActionId?: string;
  expectedStatus?: IssueStatus;
  meta?: Prisma.InputJsonObject;
  /**
   * Required for (and only for) `to = 'merged'`: written in the same UPDATE as the status because
   * `ck_issues_merged` ties `status = 'merged'` to `merged_into_id`. W-INT10.
   */
  mergedIntoId?: string;
  /** Followers left out of the after-commit notification (e.g. a reporter told separately). W-INT10. */
  notifyExcept?: string[];
}

export interface TransitionResult {
  issue: Issue;
  event: IssueEvent;
  repeated: boolean;
  /** Call after the surrounding transaction commits (transition() does this for you). */
  afterCommit: () => Promise<void>;
}

/** Verified, active, in-term representative's wards (TASK-11 `rep_scope_wards_v`; MLA/MP via constituency). */
export async function representativeWardIds(userId: string, db: Tx | typeof prisma = prisma): Promise<string[]> {
  const rows = await db.$queryRaw<{ ward_id: string }[]>`
    SELECT DISTINCT ward_id::text FROM rep_scope_wards_v WHERE user_id = ${userId}::uuid`;
  return rows.map((r) => r.ward_id);
}

/**
 * TASK-11 pre-transition hooks: run inside the transaction after the row lock and before the state-machine
 * table check (the representative ward-scope and rule-table guard registers here). Throw an AppError to refuse.
 */
export type PreTransitionHook = (
  tx: Tx,
  issue: Pick<Issue, 'id' | 'status' | 'wardId'>,
  to: IssueStatus,
  actor: TransitionActor,
  opts: TransitionOptions,
) => Promise<void>;
const preTransitionHooks: PreTransitionHook[] = [];
export function registerPreTransitionHook(hook: PreTransitionHook): void {
  if (!preTransitionHooks.includes(hook)) preTransitionHooks.push(hook);
}

/** `reporter` when the user reported this issue, else their role. */
export function actorFor(user: { id: string; role: UserRole }, issue: { reporterId: string | null }): TransitionActor {
  return { userId: user.id, kind: issue.reporterId === user.id ? 'reporter' : user.role };
}

async function attachAfterPhotos(tx: Tx, issueId: string, userId: string | null, photoIds: string[], at: Date): Promise<void> {
  const ids = [...new Set(photoIds)];
  if (ids.length !== photoIds.length || ids.length > AFTER_PHOTO_MAX || !userId) throw new AppError('PHOTO_UNUSABLE');
  const ok = await tx.photo.count({
    where: { id: { in: ids }, purpose: 'after', uploadedByUserId: userId, attachedAt: null, deletedAt: null, uploadedAt: { gt: new Date(at.getTime() - DAY_MS) } },
  });
  if (ok !== ids.length) throw new AppError('PHOTO_UNUSABLE');
  const existing = await tx.issuePhoto.count({ where: { issueId, kind: 'after' } });
  await tx.issuePhoto.createMany({ data: ids.map((photoId, i) => ({ issueId, photoId, kind: 'after' as const, position: existing + i })) });
  await tx.photo.updateMany({ where: { id: { in: ids } }, data: { attachedAt: at } });
}

/** transition() inside a caller's transaction; the caller must run `afterCommit()` once it commits. */
export async function transitionInTx(tx: Tx, issueId: string, to: IssueStatus, actor: TransitionActor, opts: TransitionOptions = {}): Promise<TransitionResult> {
  await tx.$queryRaw`SELECT id FROM issues WHERE id = ${issueId}::uuid FOR UPDATE`;
  const issue = await tx.issue.findUnique({ where: { id: issueId }, include: { category: { select: { slaDays: true } } } });
  if (!issue) throw new AppError('NOT_FOUND');
  const noop = async () => {};

  if (opts.clientActionId) {
    const prev = await tx.issueEvent.findUnique({ where: { clientActionId: opts.clientActionId } });
    if (prev) {
      if (prev.issueId !== issueId) throw new AppError('IDEMPOTENCY_KEY_REUSED');
      return { issue, event: prev, repeated: true, afterCommit: noop };
    }
  }
  if (opts.expectedStatus && opts.expectedStatus !== issue.status) {
    throw new AppError('STALE_STATUS', { details: [{ field: 'expectedStatus', issue: issue.status }] });
  }
  for (const hook of preTransitionHooks) await hook(tx, issue, to, actor, opts);
  const check = checkTransition(issue.status, to, actor.kind);
  if (!check.ok) throw new AppError(check.code);
  const { rule } = check;
  if (actor.kind === 'representative' && rule.wardScoped) {
    const wards = actor.userId ? await representativeWardIds(actor.userId, tx) : [];
    if (!issue.wardId || !wards.includes(issue.wardId)) throw new AppError('OUT_OF_WARD');
  }
  if (actor.kind === 'reporter' && rule.reporterNeedsCcrs && !issue.ccrsNumber) throw new AppError('FORBIDDEN_ROLE');
  if (rule.noteRequired && !opts.note?.trim()) {
    throw new AppError('VALIDATION_FAILED', { details: [{ field: 'note', issue: 'Add a reason.' }] });
  }
  if ((to === 'merged') !== Boolean(opts.mergedIntoId) || opts.mergedIntoId === issueId) {
    throw new AppError('VALIDATION_FAILED', { details: [{ field: 'mergedIntoId', issue: 'A merge needs one other target issue.' }] });
  }
  if (opts.photoIds?.length && to !== 'marked_fixed') {
    throw new AppError('VALIDATION_FAILED', { details: [{ field: 'photoIds', issue: 'Photos can be added only when marking fixed.' }] });
  }

  const at = clockNow();
  const data: Prisma.IssueUncheckedUpdateInput = { status: to, statusChangedAt: at, statusVersion: { increment: 1 } };
  if (to === 'marked_fixed') Object.assign(data, { markedFixedAt: at, verifiedAt: null });
  if (to === 'verified') data.verifiedAt = at;
  if (to === 'merged') data.mergedIntoId = opts.mergedIntoId;
  if (to === 'reopened') {
    Object.assign(data, { reopenedCount: { increment: 1 }, slaDueAt: new Date(at.getTime() + issue.category.slaDays * DAY_MS), overdueNotifiedAt: null, verifiedAt: null });
  }
  const updated = await tx.issue.update({ where: { id: issueId }, data });
  if (opts.photoIds?.length) await attachAfterPhotos(tx, issueId, actor.userId, opts.photoIds, at);

  const event = await tx.issueEvent.create({
    data: {
      issueId, actorId: actor.userId, actorRole: eventActorRole(actor.kind),
      type: to === 'rejected' ? 'rejected' : to === 'merged' ? 'merged' : 'status_change',
      fromStatus: issue.status, toStatus: to, note: opts.note?.trim() || null, photoId: opts.photoIds?.[0] ?? null,
      clientActionId: opts.clientActionId ?? null, meta: opts.meta ?? Prisma.JsonNull, createdAt: at,
    },
  });
  return { issue: updated, event, repeated: false, afterCommit: () => notifyStatusChange(issueId, to, actor.userId, opts.notifyExcept) };
}

/** Changes an issue's status in its own transaction, then notifies followers. Every status write goes here. */
export async function transition(issueId: string, to: IssueStatus, actor: TransitionActor, opts: TransitionOptions = {}): Promise<TransitionResult> {
  let result: TransitionResult;
  try {
    result = await prisma.$transaction((tx) => transitionInTx(tx, issueId, to, actor, opts));
  } catch (err) {
    // A concurrent repeat of the same clientActionId committed first: answer with the original event.
    if (opts.clientActionId && err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') {
      const prev = await prisma.issueEvent.findUnique({ where: { clientActionId: opts.clientActionId } });
      const issue = prev && (await prisma.issue.findUnique({ where: { id: prev.issueId } }));
      if (prev && issue && prev.issueId === issueId) return { issue, event: prev, repeated: true, afterCommit: async () => {} };
    }
    throw err;
  }
  await result.afterCommit();
  return result;
}
