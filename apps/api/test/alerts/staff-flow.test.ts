// T-08-02..06, T-08-16 (AC-1..AC-4, AC-15): composer validation, approvals, two-person rule, edit reset, roles.
import { afterAll, beforeEach, describe, expect, it } from 'vitest';
import { prisma } from '../../src/lib/db';
import { resetClock, setClock } from '../../src/lib/clock';
import { captureLogs } from '../../src/lib/logger';
import { api } from '../helpers/app';
import { resetDb } from '../helpers/db';
import { createAdmin } from '../helpers/auth';
import { useMemoryPush } from '../auth/helpers';
import { act, composer, createDraft, ist, PREFIX, staffUser, wardsFixture } from './helpers';

const NOW = ist('2030-01-10T11:00:00');
useMemoryPush();
let fx: Awaited<ReturnType<typeof wardsFixture>>;

beforeEach(async () => {
  await resetDb();
  setClock(() => NOW);
  fx = await wardsFixture();
});
afterAll(resetClock);

const wardsTarget = () => ({ scope: 'wards', wardIds: [fx.byNumber(1).id] });

describe('composer validation (T-08-02)', () => {
  it('rejects long title, http link, reversed and over-long windows with field details', async () => {
    const { auth } = await staffUser('moderator');
    const bad = [
      [{ titleEn: 'x'.repeat(90) }, 'titleEn'],
      [{ sourceUrl: 'http://ahmedabadcity.gov.in' }, 'sourceUrl'],
      [{ validTo: new Date(NOW.getTime() - 3_600_000).toISOString() }, 'validTo'],
      [{ validTo: new Date(NOW.getTime() + 20 * 86_400_000).toISOString() }, 'validTo'],
    ] as const;
    for (const [extra, field] of bad) {
      const res = await api().post(`${PREFIX}/staff/alerts`).set(auth).send(composer(wardsTarget(), extra, NOW));
      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('VALIDATION_FAILED');
      expect(res.body.error.details.map((d: { field: string }) => d.field)).toContain(field);
    }
    expect(await prisma.alert.count()).toBe(0);
  });

  it('submit with empty Gujarati → 422 ALERT_INCOMPLETE and the alert stays draft', async () => {
    const { auth } = await staffUser('moderator');
    const id = await createDraft(auth, composer(wardsTarget(), { titleGu: '', bodyGu: '' }, NOW));
    const res = await act(auth, id, 'submit');
    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe('ALERT_INCOMPLETE');
    expect((await prisma.alert.findUniqueOrThrow({ where: { id } })).status).toBe('draft');
  });
});

describe('approvals', () => {
  it('Advisory: the creator submits, approves and publishes (T-08-03)', async () => {
    const { auth } = await staffUser('moderator');
    const logs = captureLogs();
    const id = await createDraft(auth, composer(wardsTarget(), {}, NOW));
    expect((await act(auth, id, 'submit')).status).toBe(200);
    const ap = await act(auth, id, 'approve');
    expect(ap.body).toMatchObject({ approvalsNeeded: 1, status: 'pending_approval' });
    const pub = await act(auth, id, 'publish');
    logs.stop();
    expect(pub.status).toBe(200);
    expect(pub.body).toMatchObject({ status: 'published', delivery: { held: false } });
    expect(pub.body.approvedBy).toHaveLength(1);
    const line = logs.lines.find((l) => l.includes('"action":"alert_published"'));
    expect(line).toContain(id);
    expect(line).not.toContain('Water supply');
  });

  it('Warning: same person twice 409, moderator second 403, publish with one 409, admin approve + publish 200 (T-08-04)', async () => {
    const m = await staffUser('moderator');
    const m2 = await staffUser('moderator');
    const a = await staffUser('admin');
    const id = await createDraft(m.auth, composer(wardsTarget(), { severity: 'warning' }, NOW));
    await act(m.auth, id, 'submit');
    expect((await act(m.auth, id, 'approve')).status).toBe(200);
    const again = await act(m.auth, id, 'approve');
    expect([again.status, again.body.error.code]).toEqual([409, 'ALERT_ALREADY_APPROVED']);
    const second = await act(m2.auth, id, 'approve');
    expect([second.status, second.body.error.code]).toEqual([403, 'ALERT_SECOND_APPROVER_ADMIN']);
    const early = await act(a.auth, id, 'publish');
    expect([early.status, early.body.error.code]).toEqual([409, 'ALERT_APPROVALS_MISSING']);
    expect((await act(a.auth, id, 'approve')).body.approvedBy).toEqual([m.user.id, a.user.id]);
    expect((await act(a.auth, id, 'publish')).status).toBe(200);
  });

  it('a v1 admin JWT counts as an admin approver', async () => {
    const m = await staffUser('moderator');
    const v1 = await createAdmin();
    const id = await createDraft(m.auth, composer(wardsTarget(), { severity: 'critical' }, NOW));
    await act(m.auth, id, 'submit');
    await act(m.auth, id, 'approve');
    expect((await act(v1.auth, id, 'approve')).status).toBe(200);
    expect((await act(v1.auth, id, 'publish')).body.status).toBe('published');
  });

  it('two concurrent first approvals of one Warning record each actor once (T-08-05)', async () => {
    const m = await staffUser('moderator');
    const a = await staffUser('admin');
    const id = await createDraft(m.auth, composer(wardsTarget(), { severity: 'warning' }, NOW));
    await act(m.auth, id, 'submit');
    const results = await Promise.all([act(m.auth, id, 'approve'), act(m.auth, id, 'approve'), act(a.auth, id, 'approve')]);
    const row = await prisma.alert.findUniqueOrThrow({ where: { id } });
    expect(new Set(row.approvedBy).size).toBe(row.approvedBy.length);
    expect(row.approvedBy.filter((x) => x === m.user.id)).toHaveLength(1);
    expect(results.filter((r) => r.status === 409).length).toBeGreaterThanOrEqual(1);
  });

  it('editing a pending Critical returns it to draft and clears approvals (T-08-06)', async () => {
    const m = await staffUser('moderator');
    const id = await createDraft(m.auth, composer(wardsTarget(), { severity: 'critical' }, NOW));
    await act(m.auth, id, 'submit');
    await act(m.auth, id, 'approve');
    const res = await api().patch(`${PREFIX}/staff/alerts/${id}`).set(m.auth).send({ bodyEn: 'Updated message for the people of Alpha.' });
    expect(res.body).toMatchObject({ status: 'draft', approvedBy: [] });
    expect((await act(m.auth, id, 'approve')).body.error.code).toBe('ALERT_STATE_INVALID');
  });
});

describe('roles (T-08-16)', () => {
  it('no token 401, citizen 403, representative 403 on every staff route; nothing changes', async () => {
    const citizen = await staffUser('citizen');
    const rep = await staffUser('representative');
    const m = await staffUser('moderator');
    const id = await createDraft(m.auth, composer(wardsTarget(), {}, NOW));
    const calls = [
      (h: Record<string, string>) => api().get(`${PREFIX}/staff/alerts`).set(h),
      (h: Record<string, string>) => api().post(`${PREFIX}/staff/alerts`).set(h).send(composer(wardsTarget(), {}, NOW)),
      (h: Record<string, string>) => api().patch(`${PREFIX}/staff/alerts/${id}`).set(h).send({ titleEn: 'Changed title here' }),
      ...['submit', 'approve', 'publish', 'retract', 'supersede'].map((a) => (h: Record<string, string>) => api().post(`${PREFIX}/staff/alerts/${id}/${a}`).set(h).send({ reason: 'Wrong area given' })),
    ];
    for (const call of calls) {
      expect((await call({})).status).toBe(401);
      expect((await call(citizen.auth)).status).toBe(403);
      expect((await call(rep.auth)).status).toBe(403);
    }
    expect(await prisma.alert.count()).toBe(1);
    expect((await prisma.alert.findUniqueOrThrow({ where: { id } })).status).toBe('draft');
  });
});
