// TASK-14 API sweep fixes: (1) the v1 admin email login reaches every /staff route (TASK-10 §5.5 staff identity
// contract) including TASK-09 roster/election mode and TASK-12 services/initiatives/tips; (2) those actions and
// moderator status changes through POST /issues/{id}/status write exactly one audit line (REQ-S-010).
import { randomUUID } from 'node:crypto';
import { beforeEach, describe, expect, it } from 'vitest';
import { captureAudit } from '../../src/lib/audit';
import { prisma } from '../../src/lib/db';
import { api } from '../helpers/app';
import { createAdmin } from '../helpers/auth';
import { resetDb } from '../helpers/db';
import { useMemoryPush } from '../auth/helpers';
import { as, get, issueInWard, post, PREFIX, wards } from './helpers';

useMemoryPush();
const SECRET = 'SWEEP-SECRET-NOTE';

beforeEach(async () => {
  await resetDb();
});

/** Runs `fn` and returns the audit lines it wrote. */
async function audit(fn: () => Promise<{ status: number }>) {
  const cap = captureAudit();
  const res = await fn();
  cap.stop();
  return { res, lines: cap.lines };
}

describe('v1 admin login on TASK-09/12 staff routes (T-14 sweep)', () => {
  it('reads and writes services, initiatives, tips, roster and election mode', async () => {
    await wards();
    const v1 = await createAdmin();
    for (const path of ['/staff/services', '/staff/initiatives', '/staff/tips', '/staff/representatives', '/staff/settings/election-mode']) {
      expect((await get(v1.auth, path)).status, path).toBe(200);
    }
    const starts = new Date(Date.now() + 3 * 86_400_000);
    const created = await audit(() =>
      post(v1.auth, '/staff/initiatives', {
        titleEn: 'Drive', titleGu: 'ડ્રાઇવ', descriptionEn: 'A drive.', descriptionGu: 'ડ્રાઇવ.', type: 'cleanup', organiser: 'Saarthee', organiserName: 'Team',
        locationTextEn: 'Office', locationTextGu: 'ઓફિસ', startsAt: starts.toISOString(), endsAt: new Date(starts.getTime() + 3_600_000).toISOString(),
      }),
    );
    expect(created.res.status).toBe(201);
    const row = await prisma.initiative.findFirstOrThrow();
    expect(row.createdById).toBeNull();
    expect(created.lines).toHaveLength(1);
    expect(created.lines[0]).toMatchObject({ action: 'initiative.created', actorId: v1.admin.id, actorKind: 'admin_user', role: 'admin', targetId: row.id });

    const rep = await audit(() =>
      post(v1.auth, '/staff/representatives', { nameEn: 'Test Corporator', nameGu: 'ટેસ્ટ', role: 'corporator', termStart: '2021-03-01', wardNumber: 1, sourceUrl: 'https://example.org/roster', lastVerifiedAt: new Date().toISOString().slice(0, 10) }),
    );
    expect(rep.res.status).toBe(201);
    expect(rep.lines).toHaveLength(1);
    expect(rep.lines[0]).toMatchObject({ action: 'rep_created', actorId: v1.admin.id, actorKind: 'admin_user', role: 'admin', targetType: 'representative' });

    const mode = (await get(v1.auth, '/staff/settings/election-mode')).body as object;
    const put = await audit(() => api().put(`${PREFIX}/staff/settings/election-mode`).set(v1.auth).send(mode));
    expect(put.res.status).toBe(200);
    expect(put.lines).toHaveLength(1);
    expect(put.lines[0]).toMatchObject({ action: 'election_mode_set', role: 'admin', targetType: 'setting', targetId: 'election_mode' });
  });

  it('keeps the role rules: moderator reads services and roster, cannot write; citizen and visitor refused', async () => {
    const mod = await as('moderator');
    const citizen = await as('citizen');
    expect((await get(mod.auth, '/staff/services')).status).toBe(200);
    expect((await get(mod.auth, '/staff/representatives')).status).toBe(200);
    expect((await post(mod.auth, '/staff/initiatives', {})).status).toBe(403);
    expect((await api().put(`${PREFIX}/staff/settings/election-mode`).set(mod.auth).send({})).status).toBe(403);
    for (const path of ['/staff/services', '/staff/initiatives', '/staff/tips', '/staff/representatives', '/staff/settings/election-mode']) {
      expect((await get(citizen.auth, path)).status, path).toBe(403);
      expect((await get(undefined, path)).status, path).toBe(401);
    }
  });
});

describe('moderator status change via POST /issues/{id}/status (T-14 sweep)', () => {
  it('writes exactly one audit line with actor, role and target, no note', async () => {
    await wards();
    const reporter = await as('citizen');
    const mod = await as('moderator');
    const issue = await issueInWard(1, { reporterId: reporter.user.id });
    const body = { to: 'acknowledged', expectedStatus: 'reported', clientActionId: randomUUID(), note: SECRET };
    const first = await audit(() => post(mod.auth, `/issues/${issue.id}/status`, body));
    expect(first.res.status).toBe(200);
    expect(first.lines).toHaveLength(1);
    expect(first.lines[0]).toMatchObject({ action: 'issue_status_changed', actorId: mod.user.id, role: 'moderator', targetType: 'issue', targetId: issue.id });
    expect(JSON.stringify(first.lines[0])).not.toContain(SECRET);
    const replay = await audit(() => post(mod.auth, `/issues/${issue.id}/status`, body));
    expect(replay.res.status).toBe(200);
    expect(replay.lines).toHaveLength(0);
  });
});
