import { prisma } from '../../lib/db';
import { notifyUser } from '../../lib/push';
import { DEFAULT_QUIET_HOURS, DEFAULT_TZ, formatCityTime, quietHoursEnd } from '../../lib/time';

export interface RemindOptions {
  now?: Date;
  hours?: number;
  quietHours?: string;
  tz?: string;
}

/**
 * `npm run initiatives:remind` (TASK-12 §5.3, REQ-F-060; every 15 min in the job runner). Claims published
 * drives starting within INITIATIVE_REMINDER_HOURS (and more than 1 h away) whose reminder was not sent,
 * marking `reminder_sent_at` in the same transaction that reads them (FOR UPDATE SKIP LOCKED), then sends
 * one `initiative` push per `going` RSVP — deferred to the end of quiet hours when run inside them.
 * Re-running sends nothing twice. Returns the number of reminders created.
 */
export async function remindInitiatives(opts: RemindOptions = {}): Promise<{ initiatives: number; reminders: number }> {
  const now = opts.now ?? new Date();
  const hours = opts.hours ?? Number(process.env.INITIATIVE_REMINDER_HOURS ?? 24);
  const tz = opts.tz ?? process.env.TZ_CITY ?? DEFAULT_TZ;
  const quiet = opts.quietHours ?? process.env.QUIET_HOURS ?? DEFAULT_QUIET_HOURS;
  const until = new Date(now.getTime() + hours * 3_600_000);
  const minStart = new Date(now.getTime() + 3_600_000);

  const claimed = await prisma.$transaction(async (tx) => {
    const rows = await tx.$queryRaw<{ id: string }[]>`
      SELECT id FROM initiatives
      WHERE status = 'published' AND reminder_sent_at IS NULL AND starts_at <= ${until} AND starts_at > ${minStart}
      ORDER BY starts_at FOR UPDATE SKIP LOCKED`;
    if (rows.length === 0) return [];
    const ids = rows.map((r) => r.id);
    await tx.initiative.updateMany({ where: { id: { in: ids } }, data: { reminderSentAt: now } });
    return tx.initiative.findMany({
      where: { id: { in: ids } },
      include: { rsvps: { where: { status: 'going' }, select: { userId: true } } },
    });
  });

  const sendAfter = quietHoursEnd(now, quiet, tz) ?? undefined;
  let reminders = 0;
  for (const i of claimed) {
    for (const { userId } of i.rsvps) {
      await notifyUser(userId, {
        kind: 'initiative',
        refId: i.id,
        route: `/initiatives/${i.id}`,
        channel: 'updates',
        title: { en: `Tomorrow: ${i.titleEn}`, gu: `આવતીકાલે: ${i.titleGu}` },
        body: {
          en: `${formatCityTime(i.startsAt, 'en', tz)} at ${i.locationTextEn}. Tap for details.`,
          gu: `${formatCityTime(i.startsAt, 'gu', tz)}, ${i.locationTextGu}. વિગતો માટે ટૅપ કરો.`,
        },
        sendAfter,
      });
      reminders += 1;
    }
  }
  return { initiatives: claimed.length, reminders };
}
