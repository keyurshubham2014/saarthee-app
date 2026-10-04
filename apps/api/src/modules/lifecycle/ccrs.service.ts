/**
 * POST /issues/{id}/ccrs/closed (V2 TASK-06 §5.3, REQ-F-026, P1): the reporter says AMC closed the CCRS
 * complaint. No Saarthee status change; records `ccrs_closed_at` + event and arms the 24 h reopen reminder.
 */
import { config } from '../../config';
import { now as clockNow } from '../../lib/clock';
import { prisma } from '../../lib/db';
import { AppError } from '../../lib/errors';

const HOUR_MS = 3_600_000;

export async function markCcrsClosed(userId: string, issueId: string, closedAtIso?: string) {
  const issue = await prisma.issue.findUnique({ where: { id: issueId }, select: { reporterId: true, ccrsNumber: true, ccrsFiledAt: true, ccrsClosedAt: true } });
  if (!issue) throw new AppError('NOT_FOUND');
  if (issue.reporterId !== userId) throw new AppError('FORBIDDEN');
  if (!issue.ccrsNumber) throw new AppError('CCRS_NOT_LINKED');
  const deadline = (d: Date) => new Date(d.getTime() + config.CCRS_REOPEN_HOURS * HOUR_MS);
  if (issue.ccrsClosedAt) return { ccrsClosedAt: issue.ccrsClosedAt, reopenDeadline: deadline(issue.ccrsClosedAt) };

  const now = clockNow();
  const closedAt = closedAtIso ? new Date(closedAtIso) : now;
  if (closedAt.getTime() > now.getTime() + 60_000 || (issue.ccrsFiledAt && closedAt.getTime() < issue.ccrsFiledAt.getTime())) {
    throw new AppError('VALIDATION_FAILED', { details: [{ field: 'closedAt', issue: 'Choose a time between filing and now.' }] });
  }
  await prisma.$transaction(async (tx) => {
    await tx.issue.update({ where: { id: issueId }, data: { ccrsClosedAt: closedAt, ccrsReminderSentAt: null } });
    await tx.issueEvent.create({ data: { issueId, actorId: userId, actorRole: 'citizen', type: 'ccrs_closed', createdAt: now } });
  });
  return { ccrsClosedAt: closedAt, reopenDeadline: deadline(closedAt) };
}
