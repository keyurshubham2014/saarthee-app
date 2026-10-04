// T-12-09 (AC-8) attendance and RSVP list masking; T-12-11 (AC-10) cancellation notices.
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { prisma } from '../../src/lib/db';
import { api } from '../helpers/app';
import { resetDb } from '../helpers/db';
import { useMemoryPush } from '../auth/helpers';
import { captureStaffAudit, goingRsvp, inHours, makeInitiative, roleUser } from '../services/helpers';

useMemoryPush();
let audit: ReturnType<typeof captureStaffAudit>;
beforeEach(async () => {
  await resetDb();
  audit = captureStaffAudit();
});
afterEach(() => audit.restore());

describe('T-12-09 attendance', () => {
  it('lets an admin mark attendance after the start; 409 before; 403 for moderators; masked RSVP list', async () => {
    const admin = await roleUser('admin');
    const mod = await roleUser('moderator');
    const a = await roleUser('citizen', { displayName: 'Asha', phoneE164: '+919000001234' });
    const b = await roleUser('citizen', { displayName: null, phoneE164: '+919000005678' });
    const started = await makeInitiative({ startsAt: inHours(-1), endsAt: inHours(1) });
    await goingRsvp(started.id, a.user.id);
    await goingRsvp(started.id, b.user.id);
    const path = `/api/v1/staff/initiatives/${started.id}/attendance`;

    expect((await api().post(path).set(mod.auth).send({ userIds: [a.user.id], attended: true })).status).toBe(403);
    const ok = await api().post(path).set(admin.auth).send({ userIds: [a.user.id, b.user.id], attended: true });
    expect(ok.status).toBe(200);
    expect(ok.body).toEqual({ updated: 2 });
    const rows = await prisma.rsvp.findMany({ where: { initiativeId: started.id } });
    expect(rows.every((r) => r.status === 'attended' && r.attendanceMarkedBy === admin.user.id)).toBe(true);

    const list = await api().get(`/api/v1/staff/initiatives/${started.id}/rsvps`).set(admin.auth);
    expect(list.status).toBe(200);
    expect(list.body.items.map((r: Record<string, unknown>) => [r.displayName, r.phoneLast4, r.status])).toEqual([
      ['Asha', '1234', 'attended'],
      ['Resident', '5678', 'attended'],
    ]);
    expect(JSON.stringify(list.body)).not.toContain('9000001234');
    expect((await api().get(`/api/v1/staff/initiatives/${started.id}/rsvps`).set(mod.auth)).status).toBe(403);

    const future = await makeInitiative({ startsAt: inHours(5) });
    await goingRsvp(future.id, a.user.id);
    const early = await api().post(`/api/v1/staff/initiatives/${future.id}/attendance`).set(admin.auth).send({ userIds: [a.user.id], attended: true });
    expect(early.status).toBe(409);
    expect(early.body.error.code).toBe('INITIATIVE_NOT_STARTED');

    const line = audit.lines.find((l) => l.action === 'initiative.attendance_marked');
    expect(line).toMatchObject({ actor: admin.user.id, role: 'admin', targetType: 'initiative', targetId: started.id, updated: 2 });
    expect(JSON.stringify(audit.lines)).not.toMatch(/Asha|1234|userIds/);
  });
});

describe('T-12-11 cancelling a published initiative', () => {
  it('notifies every going citizen and closes RSVPs', async () => {
    const admin = await roleUser('admin');
    const i = await makeInitiative({ startsAt: inHours(48), titleEn: 'Lake clean-up' });
    const users = [await roleUser(), await roleUser(), await roleUser()];
    for (const u of users) await goingRsvp(i.id, u.user.id);
    const late = await roleUser();

    const res = await api().patch(`/api/v1/staff/initiatives/${i.id}`).set(admin.auth).send({ status: 'cancelled' });
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('cancelled');
    const notes = await prisma.notification.findMany({ where: { kind: 'initiative', refId: i.id } });
    expect(notes.map((n) => n.userId).sort()).toEqual(users.map((u) => u.user.id).sort());
    expect(notes[0]).toMatchObject({ titleEn: 'Cancelled: Lake clean-up', bodyEn: 'The organiser cancelled this drive.', route: `/initiatives/${i.id}` });

    const detail = await api().get(`/api/v1/initiatives/${i.id}`);
    expect(detail.body.status).toBe('cancelled');
    const rsvp = await api().post(`/api/v1/initiatives/${i.id}/rsvp`).set(late.auth);
    expect(rsvp.status).toBe(409);
    expect(rsvp.body.error.code).toBe('INITIATIVE_NOT_OPEN');
    expect((await api().patch(`/api/v1/staff/initiatives/${i.id}`).set(admin.auth).send({ status: 'published' })).body.error.code).toBe(
      'INVALID_TRANSITION',
    );
    expect(audit.lines.find((l) => l.action === 'initiative.status_changed')).toMatchObject({ from: 'published', to: 'cancelled' });
  });
});
