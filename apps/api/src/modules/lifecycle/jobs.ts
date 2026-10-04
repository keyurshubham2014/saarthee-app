/**
 * TASK-06 scheduled jobs (registered in src/jobs appJobs()). Both are idempotent through their
 * `*_notified_at` / `*_sent_at` columns; the runner adds the per-job advisory lock.
 */
import type { JobDefinition } from '../../jobs/types';
import { config } from '../../config';
import { prisma } from '../../lib/db';
import { notifyIssue } from './notify';
import { OPEN_STATUSES } from './transitions';

const HOUR_MS = 3_600_000;

/** sla-overdue (hourly): open issues past sla_due_at, not yet notified → event + notify reporter and followers. */
export async function runSlaOverdue(now: Date): Promise<{ flagged: number }> {
  const due = await prisma.issue.findMany({
    where: { status: { in: [...OPEN_STATUSES] }, slaDueAt: { lt: now }, overdueNotifiedAt: null },
    select: { id: true, category: { select: { slaDays: true } } },
    take: 500,
  });
  let flagged = 0;
  for (const issue of due) {
    const claimed = await prisma.$transaction(async (tx) => {
      const c = await tx.issue.updateMany({ where: { id: issue.id, overdueNotifiedAt: null }, data: { overdueNotifiedAt: now } });
      if (c.count !== 1) return false;
      await tx.issueEvent.create({ data: { issueId: issue.id, actorRole: 'system', type: 'system', note: 'overdue', createdAt: now } });
      return true;
    });
    if (!claimed) continue;
    flagged += 1;
    await notifyIssue(issue.id, 'overdue', { days: issue.category.slaDays });
  }
  return { flagged };
}

/** ccrs-reopen-reminder (every 15 min): CCRS_REMINDER_AFTER_HOURS after "AMC closed it" → one push to the reporter. */
export async function runCcrsReminder(now: Date): Promise<{ reminded: number }> {
  const before = new Date(now.getTime() - config.CCRS_REMINDER_AFTER_HOURS * HOUR_MS);
  const due = await prisma.issue.findMany({
    where: { ccrsClosedAt: { lte: before }, ccrsReminderSentAt: null, status: { notIn: ['verified', 'rejected', 'merged'] }, reporterId: { not: null } },
    select: { id: true, reporterId: true, ccrsClosedAt: true },
    take: 500,
  });
  let reminded = 0;
  for (const issue of due) {
    const c = await prisma.issue.updateMany({ where: { id: issue.id, ccrsReminderSentAt: null }, data: { ccrsReminderSentAt: now } });
    if (c.count !== 1) continue;
    reminded += 1;
    const until = new Date(issue.ccrsClosedAt!.getTime() + config.CCRS_REOPEN_HOURS * HOUR_MS);
    // Time-critical (the AMC reopen window closes): not held for quiet hours.
    await notifyIssue(issue.id, 'ccrs_reminder', { recipients: [issue.reporterId!], until, ignoreQuietHours: true });
  }
  return { reminded };
}

export const lifecycleJobs: JobDefinition[] = [
  { name: 'sla-overdue', cron: '5 * * * *', run: async ({ now }) => runSlaOverdue(now) },
  { name: 'ccrs-reopen-reminder', everyMs: 15 * 60_000, run: async ({ now }) => runCcrsReminder(now) },
];
