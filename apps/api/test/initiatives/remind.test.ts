// T-12-08 (AC-7): 24-hour reminder job — one notification per going RSVP, idempotent, quiet hours queue.
import { beforeEach, describe, expect, it } from 'vitest';
import { prisma } from '../../src/lib/db';
import { isQuietHours, quietHoursEnd } from '../../src/lib/time';
import { remindInitiatives } from '../../src/modules/initiatives/remind';
import { jobs as initiativeJobs } from '../../src/modules/initiatives/jobs';
import { jobs as serviceJobs } from '../../src/modules/services/jobs';
import { resetDb } from '../helpers/db';
import { useMemoryPush } from '../auth/helpers';
import { goingRsvp, inHours, makeInitiative, roleUser } from '../services/helpers';

useMemoryPush();
beforeEach(resetDb);

/** "HH:MM-HH:MM" (Asia/Kolkata) window that contains now and ends ~2 h later. */
function windowAroundNow(): string {
  const ist = (d: Date) =>
    new Intl.DateTimeFormat('en-GB', { timeZone: 'Asia/Kolkata', hour: '2-digit', minute: '2-digit', hourCycle: 'h23' }).format(d);
  return `${ist(inHours(-1))}-${ist(inHours(2))}`;
}

async function scenario() {
  const i = await makeInitiative({ startsAt: inHours(23), titleEn: 'Canal clean-up', titleGu: 'કેનાલ સફાઈ' });
  const a = await roleUser();
  const b = await roleUser();
  const c = await roleUser();
  await goingRsvp(i.id, a.user.id);
  await goingRsvp(i.id, b.user.id);
  await goingRsvp(i.id, c.user.id, 'cancelled');
  await makeInitiative({ startsAt: inHours(30) }); // outside the 24 h window
  await makeInitiative({ startsAt: inHours(0.5) }); // less than 1 h away
  await makeInitiative({ startsAt: inHours(20), status: 'draft' });
  return { i, a, b };
}

describe('T-12-08 initiatives:remind', () => {
  it('sends one reminder per going RSVP, sets reminder_sent_at, and sends nothing on a second run', async () => {
    const { i, a, b } = await scenario();
    const first = await remindInitiatives({ quietHours: '00:00-00:00' });
    expect(first).toEqual({ initiatives: 1, reminders: 2 });
    const rows = await prisma.notification.findMany({ where: { kind: 'initiative' } });
    expect(rows.map((r) => r.userId).sort()).toEqual([a.user.id, b.user.id].sort());
    for (const r of rows) {
      expect(r).toMatchObject({ refId: i.id, route: `/initiatives/${i.id}`, channel: 'updates', titleEn: 'Tomorrow: Canal clean-up', titleGu: 'આવતીકાલે: કેનાલ સફાઈ' });
      expect(r.bodyEn).toMatch(/ at Gate 1\. Tap for details\.$/);
      expect(r.bodyGu).toContain('ગેટ 1');
      expect(r.status).not.toBe('queued');
    }
    expect((await prisma.initiative.findUniqueOrThrow({ where: { id: i.id } })).reminderSentAt).toBeInstanceOf(Date);
    expect(await remindInitiatives({ quietHours: '00:00-00:00' })).toEqual({ initiatives: 0, reminders: 0 });
    expect(await prisma.notification.count()).toBe(2);
  });

  it('queues reminders with send_after at the end of quiet hours', async () => {
    await scenario();
    const quiet = windowAroundNow();
    await remindInitiatives({ quietHours: quiet });
    const rows = await prisma.notification.findMany({ where: { kind: 'initiative' } });
    expect(rows).toHaveLength(2);
    const end = quietHoursEnd(new Date(), quiet, 'Asia/Kolkata')!;
    for (const r of rows) {
      expect(r.status).toBe('queued');
      expect(Math.abs(r.sendAfter!.getTime() - end.getTime())).toBeLessThan(120_000);
    }
  });

  it('two concurrent runs send each reminder once', async () => {
    await scenario();
    const [r1, r2] = await Promise.all([remindInitiatives({ quietHours: '00:00-00:00' }), remindInitiatives({ quietHours: '00:00-00:00' })]);
    expect(r1.reminders + r2.reminders).toBe(2);
    expect(await prisma.notification.count()).toBe(2);
  });

  it('exports job definitions for the TASK-06 runner', () => {
    expect(initiativeJobs.map((j) => [j.name, j.everyMs])).toEqual([['initiatives-remind', 900_000]]);
    expect(serviceJobs.map((j) => [j.name, j.cron, j.tz])).toEqual([['services-check-links', '0 6 1 * *', 'Asia/Kolkata']]);
  });
});

describe('quiet hours helper', () => {
  it('handles a window that wraps midnight in Asia/Kolkata', () => {
    // 23:30 IST = 18:00 UTC; 06:59 IST = 01:29 UTC; 07:00 IST = 01:30 UTC; 12:00 IST = 06:30 UTC.
    expect(isQuietHours(new Date('2027-01-10T18:00:00Z'))).toBe(true);
    expect(isQuietHours(new Date('2027-01-11T01:29:00Z'))).toBe(true);
    expect(isQuietHours(new Date('2027-01-11T01:30:00Z'))).toBe(false);
    expect(isQuietHours(new Date('2027-01-11T06:30:00Z'))).toBe(false);
    expect(quietHoursEnd(new Date('2027-01-10T18:00:00Z'))?.toISOString()).toBe('2027-01-11T01:30:00.000Z');
    expect(quietHoursEnd(new Date('2027-01-11T00:00:00Z'))?.toISOString()).toBe('2027-01-11T01:30:00.000Z');
    expect(quietHoursEnd(new Date('2027-01-11T06:30:00Z'))).toBeNull();
  });
});
