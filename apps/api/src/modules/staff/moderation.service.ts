/**
 * Moderation actions (TASK-10 §5.3). Each runs in one transaction with a row lock and appends issue_events.
 * Status writes go only through TASK-06's `transitionInTx()` (via status.service `transitionAsStaff`), inside the
 * same transaction as the side effects; its `afterCommit()` notifications run after commit (W-INT10).
 */
import { now } from '../../lib/clock';
import { prisma } from '../../lib/db';
import { AppError } from '../../lib/errors';
import { logger } from '../../lib/logger';
import { notifyUser } from '../../lib/push';
import { REASON_TEXT, type RejectReason } from './reject-reasons';
import { lockIssue, TERMINAL_OPEN, transitionAsStaff, type StatusActor } from './status.service';

export { REJECT_REASONS, type RejectReason } from './reject-reasons';

const stamp = (actor: StatusActor) => ({ moderatedAt: now(), moderatedBy: actor.actorId });

async function actionFlags(tx: Parameters<Parameters<typeof prisma.$transaction>[0]>[0], issueIds: string[], actor: StatusActor) {
  await tx.moderationFlag.updateMany({
    where: { issueId: { in: issueIds }, status: 'open' },
    data: { status: 'actioned', handledAt: now(), handledBy: actor.handlerId },
  });
}

export async function rejectIssue(id: string, actor: StatusActor, reason: RejectReason, note?: string) {
  const { issue, afterCommit } = await prisma.$transaction(async (tx) => {
    const locked = await lockIssue(tx, id);
    if (!TERMINAL_OPEN.includes(locked.status)) throw new AppError('ISSUE_STATE_INVALID');
    // The reporter gets the reason-specific message below; other followers get TASK-06's "Issue closed".
    const t = await transitionAsStaff(tx, id, 'rejected', actor, {
      note: note ? `${reason}: ${note}` : reason,
      notifyExcept: locked.reporter_id ? [locked.reporter_id] : [],
    });
    await tx.issue.update({ where: { id }, data: stamp(actor) });
    await actionFlags(tx, [id], actor);
    return { issue: locked, afterCommit: t.afterCommit };
  });
  await afterCommit();
  if (issue.reporter_id) {
    const text = REASON_TEXT[reason];
    await notifyUser(issue.reporter_id, {
      kind: 'issue_update', refId: id, route: `/issues/${id}`, channel: 'updates',
      title: { en: "Your report wasn't accepted", gu: 'તમારો રિપોર્ટ સ્વીકારાયો નથી' },
      body: { en: `Your report wasn't accepted: ${text.en}`, gu: `તમારો રિપોર્ટ સ્વીકારાયો નથી. કારણ: ${text.gu}.` },
    }).catch((err: unknown) => logger.warn({ err, issueId: id }, 'reject_notify_failed'));
  }
}

export async function mergeIssue(id: string, targetId: string, actor: StatusActor, note?: string) {
  if (id === targetId) throw new AppError('MERGE_INVALID');
  const afterCommit = await prisma.$transaction(async (tx) => {
    // Lock in a stable order to avoid deadlocks between opposite merges.
    const [first, second] = [id, targetId].sort();
    const a = await lockIssue(tx, first!);
    const b = await lockIssue(tx, second!);
    const source = a.id === id ? a : b;
    const target = a.id === id ? b : a;
    if (!TERMINAL_OPEN.includes(source.status)) throw new AppError('ISSUE_STATE_INVALID');
    if (!TERMINAL_OPEN.includes(target.status) || target.status === 'marked_fixed' || target.visibility === 'hidden') {
      throw new AppError('MERGE_INVALID');
    }
    const t = await transitionAsStaff(tx, id, 'merged', actor, { note: note ?? null, mergedIntoId: targetId });
    await tx.issue.update({ where: { id }, data: stamp(actor) });
    await tx.$executeRaw`
      INSERT INTO me_toos (issue_id, user_id, created_at)
      SELECT ${targetId}::uuid, m.user_id, m.created_at FROM me_toos m
      WHERE m.issue_id = ${id}::uuid AND m.user_id IS DISTINCT FROM ${target.reporter_id}::uuid
      ON CONFLICT DO NOTHING`;
    await tx.$executeRaw`
      INSERT INTO follows (issue_id, user_id, created_at)
      SELECT ${targetId}::uuid, f.user_id, f.created_at FROM follows f WHERE f.issue_id = ${id}::uuid
      ON CONFLICT DO NOTHING`;
    if (source.reporter_id) {
      await tx.$executeRaw`
        INSERT INTO follows (issue_id, user_id) VALUES (${targetId}::uuid, ${source.reporter_id}::uuid) ON CONFLICT DO NOTHING`;
    }
    await tx.$executeRaw`
      UPDATE issues SET
        me_too_count = (SELECT count(*) FROM me_toos WHERE issue_id = ${targetId}::uuid),
        follower_count = (SELECT count(*) FROM follows WHERE issue_id = ${targetId}::uuid)
      WHERE id = ${targetId}::uuid`;
    await tx.issueEvent.create({
      data: { issueId: targetId, actorId: actor.actorId, actorRole: actor.actorRole, type: 'merged', note: `merged_from:${id}`, createdAt: now() },
    });
    await actionFlags(tx, [id], actor);
    return t.afterCommit;
  });
  await afterCommit();
}

export async function recategoriseIssue(
  id: string,
  actor: StatusActor,
  input: { categoryId?: string; wardId?: string; note?: string },
): Promise<{ categoryChanged: boolean; wardChanged: boolean }> {
  return prisma.$transaction(async (tx) => {
    const issue = await lockIssue(tx, id);
    if (!TERMINAL_OPEN.includes(issue.status)) throw new AppError('ISSUE_STATE_INVALID');
    let categoryChanged = false;
    let wardChanged = false;
    if (input.categoryId && input.categoryId !== issue.category_id) {
      const category = await tx.category.findUnique({ where: { id: input.categoryId } });
      if (!category || !category.isActive) throw new AppError('CATEGORY_INACTIVE');
      const slaDueAt = new Date(issue.created_at.getTime() + category.slaDays * 86_400_000);
      await tx.issue.update({ where: { id }, data: { categoryId: category.id, slaDueAt, isSensitive: category.sensitive } });
      await tx.issueEvent.create({
        data: { issueId: id, actorId: actor.actorId, actorRole: actor.actorRole, type: 'recategorised', note: input.note ?? null, createdAt: now() },
      });
      categoryChanged = true;
    }
    if (input.wardId && input.wardId !== issue.ward_id) {
      const ward = await tx.ward.findUnique({ where: { id: input.wardId }, select: { id: true, zoneId: true } });
      if (!ward) throw new AppError('WARD_NOT_FOUND');
      await tx.issue.update({ where: { id }, data: { wardId: ward.id, zoneId: ward.zoneId } });
      await tx.issueEvent.create({
        data: { issueId: id, actorId: actor.actorId, actorRole: actor.actorRole, type: 'ward_changed', note: input.note ?? null, createdAt: now() },
      });
      wardChanged = true;
    }
    return { categoryChanged, wardChanged };
  });
}

/** "Looks fine": stamps moderated_at/by; a sensitive issue awaiting review becomes public. */
export async function markReviewed(id: string, actor: StatusActor) {
  await prisma.$transaction(async (tx) => {
    const issue = await lockIssue(tx, id);
    if (!TERMINAL_OPEN.includes(issue.status) && issue.status !== 'verified') throw new AppError('ISSUE_STATE_INVALID');
    if (issue.moderated_at) throw new AppError('ISSUE_STATE_INVALID');
    const publish = issue.is_sensitive && issue.visibility === 'hidden';
    await tx.issue.update({ where: { id }, data: { ...stamp(actor), ...(publish ? { visibility: 'public' } : {}) } });
    await tx.issueEvent.create({ data: { issueId: id, actorId: actor.actorId, actorRole: actor.actorRole, type: 'reviewed', createdAt: now() } });
  });
}

export async function setHidden(id: string, actor: StatusActor, hidden: boolean, reason: string) {
  await prisma.$transaction(async (tx) => {
    const issue = await lockIssue(tx, id);
    if ((issue.visibility === 'hidden') === hidden) throw new AppError('ISSUE_STATE_INVALID');
    await tx.issue.update({ where: { id }, data: { visibility: hidden ? 'hidden' : 'public', ...stamp(actor) } });
    await tx.issueEvent.create({
      data: { issueId: id, actorId: actor.actorId, actorRole: actor.actorRole, type: hidden ? 'hidden' : 'unhidden', note: reason, createdAt: now() },
    });
    if (hidden) await actionFlags(tx, [id], actor);
  });
}

/** Hides a comment (an issue_events row of type `comment`); idempotent. Returns the issue id. */
export async function hideComment(eventId: string, actor: StatusActor): Promise<string> {
  const event = await prisma.issueEvent.findUnique({ where: { id: eventId }, select: { id: true, issueId: true, type: true } });
  if (!event || event.type !== 'comment') throw new AppError('NOT_FOUND');
  await prisma.$transaction(async (tx) => {
    await tx.issueEventHide.upsert({
      where: { eventId },
      create: { eventId, issueId: event.issueId, hiddenBy: actor.handlerId },
      update: {},
    });
    await tx.moderationFlag.updateMany({
      where: { targetType: 'issue_event', targetId: eventId, status: 'open' },
      data: { status: 'actioned', handledAt: now(), handledBy: actor.handlerId },
    });
  });
  return event.issueId;
}

export async function resolveFlag(id: string, actor: StatusActor, outcome: 'actioned' | 'dismissed') {
  const res = await prisma.moderationFlag.updateMany({
    where: { id, status: 'open' },
    data: { status: outcome, handledAt: now(), handledBy: actor.handlerId },
  });
  if (res.count === 0) {
    const exists = await prisma.moderationFlag.count({ where: { id } });
    throw new AppError(exists ? 'ISSUE_STATE_INVALID' : 'NOT_FOUND');
  }
}
