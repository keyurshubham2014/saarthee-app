// T-10-02 (AC-13): every TASK-10 staff mutation writes exactly one audit line with actor, kind, role, action,
// target type and id — and no phone, name, note, reason text or body.
import { describe, expect, it } from 'vitest';
import { captureAudit, STAFF_AUDIT_ACTIONS } from '../../src/lib/audit';
import { prisma } from '../../src/lib/db';
import { api } from '../helpers/app';
import { resetDb } from '../helpers/db';
import { makePhoto } from '../helpers/factories';
import { useMemoryPush } from '../auth/helpers';
import { as, comment, issueInWard, makeCategory, post, PREFIX, wards } from './helpers';

useMemoryPush();
const SECRET_NOTE = 'NOTE-SECRET-TEXT';
const REQUIRED = ['actorId', 'actorKind', 'role', 'action', 'targetType', 'targetId'];

describe('audit (T-10-02)', () => {
  it('one line per mutation, ids and enums only', async () => {
    await resetDb();
    const w = await wards();
    const admin = await as('admin', { displayName: 'Admin NAME-SECRET' });
    const mod = await as('moderator');
    const reporter = await as('citizen', { phoneE164: '+919999977777', displayName: 'Reporter NAME-SECRET' });
    const [i1, i2, i3, i4, i5] = await Promise.all([1, 1, 1, 2, 2].map(() => issueInWard(1, { reporterId: reporter.user.id })));
    const cat = await makeCategory();
    const ev = await comment(i5!.id, reporter.user.id);
    const flag = await post(reporter.auth, `/issues/${i5!.id}/flags`, { reason: 'spam', note: SECRET_NOTE });
    const photo = await makePhoto({ uploadedByUserId: mod.user.id, attachedAt: null });

    const steps: [string, () => Promise<{ status: number }>][] = [
      ['issue_rejected', () => post(mod.auth, `/staff/issues/${i1!.id}/reject`, { reason: 'spam', note: SECRET_NOTE })],
      ['issue_merged', () => post(mod.auth, `/staff/issues/${i2!.id}/merge`, { targetIssueId: i3!.id, note: SECRET_NOTE })],
      ['issue_recategorised', () => post(mod.auth, `/staff/issues/${i3!.id}/recategorise`, { categoryId: cat.id, note: SECRET_NOTE })],
      ['issue_ward_changed', () => post(mod.auth, `/staff/issues/${i3!.id}/recategorise`, { wardId: w.byNumber(2).id })],
      ['issue_hidden', () => post(mod.auth, `/staff/issues/${i4!.id}/hide`, { reason: SECRET_NOTE })],
      ['issue_unhidden', () => post(mod.auth, `/staff/issues/${i4!.id}/unhide`, { reason: SECRET_NOTE })],
      ['issue_reviewed', () => post(mod.auth, `/staff/issues/${i5!.id}/reviewed`)],
      ['issue_status_changed', () => post(mod.auth, `/staff/issues/${i4!.id}/status`, { to: 'marked_fixed', note: SECRET_NOTE, photoIds: [photo.id] })],
      ['flag_resolved', () => post(mod.auth, `/staff/flags/${flag.body.flagId}/resolve`, { outcome: 'dismissed' })],
      ['comment_hidden', () => post(mod.auth, `/staff/comments/${ev.id}/hide`, { reason: SECRET_NOTE })],
      ['user_suspended', () => post(mod.auth, `/staff/users/${reporter.user.id}/suspend`, { reason: SECRET_NOTE })],
      ['user_unsuspended', () => post(mod.auth, `/staff/users/${reporter.user.id}/unsuspend`, { reason: SECRET_NOTE })],
      ['role_changed', () => post(admin.auth, `/staff/users/${reporter.user.id}/role`, { role: 'moderator' })],
      ['category_created', () => post(admin.auth, '/staff/categories', { slug: 'footpaths', nameEn: 'Footpaths NAME-SECRET', nameGu: 'ફૂટપાથ', icon: 'road', colourToken: 'category.roads', slaDays: 5, sensitive: false, isActive: true, sortOrder: 20 })],
      ['category_updated', () => api().patch(`${PREFIX}/staff/categories/${cat.id}`).set(admin.auth).send({ nameEn: 'Renamed NAME-SECRET' })],
      ['setting_changed', () => api().put(`${PREFIX}/staff/settings/relay_enabled`).set(admin.auth).send({ value: false })],
      ['export_downloaded', () => api().get(`${PREFIX}/staff/export?dataset=issues&from=2026-01-01&to=2026-12-31`).set(admin.auth)],
    ];
    const seen = new Set<string>();
    for (const [action, run] of steps) {
      const audit = captureAudit();
      const res = await run();
      audit.stop();
      expect(res.status, action).toBeLessThan(300);
      expect(audit.lines, action).toHaveLength(1);
      const line = audit.lines[0]!;
      expect(line.action).toBe(action);
      for (const k of REQUIRED) expect(line[k], `${action}.${k}`).toBeTruthy();
      const text = JSON.stringify(line);
      for (const bad of [SECRET_NOTE, 'NAME-SECRET', '9999977777']) expect(text, `${action} leaks ${bad}`).not.toContain(bad);
      for (const key of ['note', 'body', 'phone', 'displayName', 'name']) expect(Object.keys(line), action).not.toContain(key);
      seen.add(action);
    }
    // TASK-11 actions (rep_*, ward_export) are covered by test/representatives/t11-*.test.ts.
    expect([...seen].sort()).toEqual(STAFF_AUDIT_ACTIONS.filter((a) => !a.startsWith('rep_') && a !== 'ward_export').sort());
    expect(await prisma.issue.count({ where: { status: 'rejected' } })).toBe(1);
  });
});
