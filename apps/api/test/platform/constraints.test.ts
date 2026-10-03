// T-01-02..04 (AC-4, AC-5, AC-6): named constraints, the location trigger and append-only history.
import { randomUUID } from 'node:crypto';
import { beforeEach, describe, expect, it } from 'vitest';
import { prisma, withLegacyWrite } from '../../src/lib/db';
import { dbError, resetDb, sqlError } from '../helpers/db';
import { makeCategory, makeIssue, makeUser } from '../helpers/factories';

beforeEach(resetDb);

const INSERT_USER = 'INSERT INTO users (phone_e164, firebase_uid, role, status) VALUES ($1, $2, $3::user_role, $4::user_status)';
const insertUser = (phone: string | null, uid: string | null, role = 'citizen', status = 'active') =>
  prisma.$executeRaw`INSERT INTO users (phone_e164, firebase_uid, role, status)
    VALUES (${phone}, ${uid}, ${role}::user_role, ${status}::user_status)`;
const userError = (phone: string | null, uid: string | null, role = 'citizen', status = 'active') =>
  sqlError(INSERT_USER, [phone, uid, role, status]);

describe('users, consents, devices', () => {
  beforeEach(async () => {
    await insertUser('+919000000001', 'u1');
  });

  it('rejects a duplicate phone (uq_users_phone)', async () => {
    expect(await userError('+919000000001', 'u2')).toContain('uq_users_phone');
  });

  it('rejects a duplicate firebase uid (uq_users_firebase_uid)', async () => {
    expect(await userError('+919000000002', 'u1')).toContain('uq_users_firebase_uid');
  });

  it('rejects an unknown role (enum)', async () => {
    expect(await userError('+919000000003', 'u3', 'superuser')).toContain('invalid input value for enum user_role');
  });

  it('rejects a phone that is not E.164 (ck_users_phone)', async () => {
    expect(await userError('9000000001', 'u4')).toContain('ck_users_phone');
  });

  it('requires a deleted user to have no phone or uid (ck_users_deleted)', async () => {
    expect(await userError('+919000000005', null, 'citizen', 'deleted')).toContain('ck_users_deleted');
    await expect(insertUser(null, null, 'citizen', 'deleted')).resolves.toBe(1);
  });

  it('requires an active user to have a firebase uid (ck_users_active_identity)', async () => {
    expect(await userError('+919000000006', null)).toContain('ck_users_active_identity');
  });

  it('allows one active consent per purpose; withdrawing allows a re-grant (uq_consents_active)', async () => {
    const u = await makeUser();
    const grant = () =>
      prisma.$executeRaw`INSERT INTO consents (user_id, purpose, text_version) VALUES (${u.id}::uuid, 'notifications', 'v2')`;
    await grant();
    expect(
      await sqlError("INSERT INTO consents (user_id, purpose, text_version) VALUES ($1::uuid, 'notifications', 'v2')", [u.id]),
    ).toContain('uq_consents_active');
    await prisma.consent.updateMany({ where: { userId: u.id }, data: { withdrawnAt: new Date(Date.now() + 1000) } });
    await expect(grant()).resolves.toBe(1);
    expect(await prisma.consent.count({ where: { userId: u.id } })).toBe(2);
  });

  it('rejects a second device with the same install id (uq_devices_install)', async () => {
    const installId = randomUUID();
    const add = () =>
      prisma.$executeRaw`INSERT INTO devices (install_id, platform, app_version) VALUES (${installId}::uuid, 'android', '2.0.0')`;
    await add();
    expect(
      await sqlError("INSERT INTO devices (install_id, platform, app_version) VALUES ($1::uuid, 'android', '2.0.0')", [installId]),
    ).toContain('uq_devices_install');
  });
});

describe('issues', () => {
  it('fills location from lat/lng with the trigger', async () => {
    const issue = await makeIssue({ lat: 23.012345, lng: 72.561234 });
    const [row] = await prisma.$queryRaw<{ wkt: string }[]>`
      SELECT ST_AsText(location::geometry) AS wkt FROM issues WHERE id = ${issue.id}::uuid`;
    expect(row!.wkt).toBe('POINT(72.561234 23.012345)');
    await prisma.issue.update({ where: { id: issue.id }, data: { lat: 23.1, lng: 72.6 } });
    const [moved] = await prisma.$queryRaw<{ wkt: string }[]>`
      SELECT ST_AsText(location::geometry) AS wkt FROM issues WHERE id = ${issue.id}::uuid`;
    expect(moved!.wkt).toBe('POINT(72.6 23.1)');
  });

  it('rejects out-of-range coordinates (ck_issues_coords)', async () => {
    expect(await dbError(makeIssue({ lat: 91 }))).toContain('ck_issues_coords');
  });

  it('rejects a 1,001-character description', async () => {
    expect(await dbError(makeIssue({ description: 'x'.repeat(1001) }))).toMatch(/too long|22001/);
    await expect(makeIssue({ description: 'x'.repeat(1000) })).resolves.toBeTruthy();
  });

  it('rejects a repeated client_submission_id (uq_issues_client_submission)', async () => {
    const cat = await makeCategory();
    const id = randomUUID();
    const add = () =>
      prisma.$executeRaw`INSERT INTO issues (client_submission_id, category_id, title, lat, lng, sla_due_at)
        VALUES (${id}::uuid, ${cat.id}::uuid, 't', 23, 72.5, now())`;
    await add();
    expect(
      await sqlError(
        "INSERT INTO issues (client_submission_id, category_id, title, lat, lng, sla_due_at) VALUES ($1::uuid, $2::uuid, 't', 23, 72.5, now())",
        [id, cat.id],
      ),
    ).toContain('uq_issues_client_submission');
  });

  it('has a GIST index on location and the status index', async () => {
    const rows = await prisma.$queryRaw<{ indexname: string; indexdef: string }[]>`
      SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'issues'`;
    const byName = new Map(rows.map((r) => [r.indexname, r.indexdef]));
    expect(byName.get('idx_issues_location')).toMatch(/USING gist \(location\)/);
    expect(byName.get('idx_issues_status')).toMatch(/\(status, status_changed_at DESC\)/);
    expect(byName.get('idx_issues_sla_open')).toMatch(/WHERE/);
  });
});

describe('issue children', () => {
  it('rejects a repeated me-too (PK) and negative counters (ck_issues_counts)', async () => {
    const [issue, u] = [await makeIssue(), await makeUser()];
    await prisma.meToo.create({ data: { issueId: issue.id, userId: u.id } });
    expect(await sqlError('INSERT INTO me_toos (issue_id, user_id) VALUES ($1::uuid, $2::uuid)', [issue.id, u.id])).toContain('pk_me_toos');
    expect(await dbError(prisma.$executeRaw`UPDATE issues SET me_too_count = -1 WHERE id = ${issue.id}::uuid`)).toContain('ck_issues_counts');
  });

  it('allows one verification per user, issue and day (uq_issue_verifications_daily)', async () => {
    const [issue, a] = [await makeIssue(), await makeUser()];
    const verify = (day: string) =>
      prisma.$executeRaw`INSERT INTO issue_verifications (issue_id, user_id, answer, created_day)
        VALUES (${issue.id}::uuid, ${a.id}::uuid, 'fixed', ${day}::date)`;
    await verify('2026-10-04');
    expect(
      await sqlError(
        "INSERT INTO issue_verifications (issue_id, user_id, answer, created_day) VALUES ($1::uuid, $2::uuid, 'fixed', '2026-10-04')",
        [issue.id, a.id],
      ),
    ).toContain('uq_issue_verifications_daily');
    await expect(verify('2026-10-05')).resolves.toBe(1);
  });

  it('keeps issue_events append-only unless the maintenance bypass is on', async () => {
    const issue = await makeIssue();
    const ev = await prisma.issueEvent.create({
      data: { issueId: issue.id, actorRole: 'system', type: 'status_change', toStatus: 'reported' },
    });
    expect(await dbError(prisma.issueEvent.update({ where: { id: ev.id }, data: { note: 'x' } }))).toContain('ISSUE_EVENTS_APPEND_ONLY');
    expect(await dbError(prisma.issueEvent.delete({ where: { id: ev.id } }))).toContain('ISSUE_EVENTS_APPEND_ONLY');
    await withLegacyWrite((tx) => tx.issueEvent.update({ where: { id: ev.id }, data: { actorId: null } }));
  });

  it('requires a status_change event to have to_status (ck_issue_events_status)', async () => {
    const issue = await makeIssue();
    expect(
      await dbError(prisma.$executeRaw`INSERT INTO issue_events (issue_id, actor_role, type) VALUES (${issue.id}::uuid, 'system', 'status_change')`),
    ).toContain('ck_issue_events_status');
  });

  it('requires merged ⇔ merged_into_id (ck_issues_merged)', async () => {
    const canonical = await makeIssue();
    expect(await dbError(makeIssue({ status: 'merged' }))).toContain('ck_issues_merged');
    expect(await dbError(makeIssue({ status: 'reported', mergedIntoId: canonical.id }))).toContain('ck_issues_merged');
    await expect(makeIssue({ status: 'merged', mergedIntoId: canonical.id })).resolves.toBeTruthy();
  });
});
