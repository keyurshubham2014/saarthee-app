// T-10-12 (AC-11) categories + settings, T-10-13 (AC-12) exports, T-10-14 (AC-14) retired v1 routes.
import { beforeEach, describe, expect, it } from 'vitest';
import { prisma, withLegacyWrite } from '../../src/lib/db';
import { captureAudit } from '../../src/lib/audit';
import { reporterRef } from '../../src/modules/staff/export.routes';
import { api } from '../helpers/app';
import { createAdmin } from '../helpers/auth';
import { resetDb } from '../helpers/db';
import { as, get, makeCategory, makeIssue, PREFIX } from './helpers';

beforeEach(resetDb);

const put = (auth: Record<string, string>, path: string, body: object) => api().put(`${PREFIX}${path}`).set(auth).send(body);
const patch = (auth: Record<string, string>, path: string, body: object) => api().patch(`${PREFIX}${path}`).set(auth).send(body);

describe('categories and settings (T-10-12)', () => {
  it('validates SLA and colour, keeps slug immutable, shows renames publicly', async () => {
    const admin = await as('admin');
    const mod = await as('moderator');
    const cat = await makeCategory({ slug: 'roads', colourToken: 'category.roads', icon: 'road' });
    await patch(admin.auth, `/staff/categories/${cat.id}`, { nameGu: 'રસ્તા' }).expect(200);
    const pub = await get(undefined, '/categories').expect(200);
    expect(pub.body.items.find((c: { id: string }) => c.id === cat.id).nameGu).toBe('રસ્તા');
    expect((await patch(admin.auth, `/staff/categories/${cat.id}`, { slaDays: 0 })).status).toBe(400);
    expect((await patch(admin.auth, `/staff/categories/${cat.id}`, { colourToken: 'sunrise' })).status).toBe(400);
    expect((await patch(admin.auth, `/staff/categories/${cat.id}`, { slug: 'paths' })).status).toBe(400);
    const body = { slug: 'roads', nameEn: 'Roads', nameGu: 'રસ્તા', icon: 'road', colourToken: 'category.roads', slaDays: 7, sensitive: false, isActive: true, sortOrder: 1 };
    expect((await api().post(`${PREFIX}/staff/categories`).set(admin.auth).send(body)).body.error.code).toBe('SLUG_TAKEN');
    await api().post(`${PREFIX}/staff/categories`).set(admin.auth).send({ ...body, slug: 'footpaths' }).expect(201);
    expect((await get(mod.auth, '/staff/categories')).status).toBe(200);
    expect((await patch(mod.auth, `/staff/categories/${cat.id}`, { nameEn: 'x' })).status).toBe(403);
  });

  it('stores allow-listed flags with updated_by; unknown key 400; moderator 403; election mode via TASK-09', async () => {
    const admin = await as('admin');
    const mod = await as('moderator');
    const list = await get(mod.auth, '/staff/settings').expect(200);
    expect(list.body.items.find((i: { key: string }) => i.key === 'relay_enabled')).toMatchObject({ value: true, isDefault: true });
    await put(admin.auth, '/staff/settings/relay_enabled', { value: false }).expect(200);
    const row = await prisma.appSetting.findUniqueOrThrow({ where: { key: 'relay_enabled' } });
    expect(row).toMatchObject({ value: false, updatedBy: admin.user.id });
    expect((await put(admin.auth, '/staff/settings/relay_enabled', { value: 'no' })).status).toBe(400);
    expect((await put(admin.auth, '/staff/settings/dark_mode', { value: true })).body.error.code).toBe('SETTING_UNKNOWN');
    expect((await put(mod.auth, '/staff/settings/relay_enabled', { value: true })).status).toBe(403);
    const election = { enabled: true, scope: 'city', wardIds: [], from: '2030-01-01T00:00:00+05:30', to: '2030-01-10T00:00:00+05:30', note_en: 'Polls', note_gu: 'ચૂંટણી' };
    await put(admin.auth, '/staff/settings/election_mode', { value: election }).expect(200);
    const em = await get(admin.auth, '/staff/settings/election-mode').expect(200);
    expect(em.body).toMatchObject({ enabled: true, scope: 'city', note_en: 'Polls' });
  });
});

describe('exports (T-10-13)', () => {
  const q = '/staff/export?dataset=issues&from=2026-09-01&to=2026-09-30';

  it('omits phones by default, needs a reason to include them, escapes formulas, audits, 403 for moderators', async () => {
    const admin = await as('admin');
    const reporter = await as('citizen', { phoneE164: '+919999911111' });
    await makeIssue({ reporterId: reporter.user.id, title: '=HYPERLINK("x")', createdAt: new Date('2026-09-10T06:00:00Z') });
    await makeIssue({ createdAt: new Date('2026-10-10T06:00:00Z') }); // outside the range
    const plain = await get(admin.auth, q).expect(200);
    expect(plain.headers['content-type']).toContain('text/csv');
    expect(plain.headers['content-disposition']).toContain('saarthee-issues-2026-09-01-to-2026-09-30.csv');
    const lines = plain.text.trim().split('\r\n');
    expect(lines).toHaveLength(2);
    expect(lines[0]).toContain('"reporter_ref"');
    expect(lines[0]).not.toContain('phone');
    expect(plain.text).not.toContain('9999911111');
    expect(lines[1]).toContain(`"${reporterRef(reporter.user.id)}"`);
    expect(lines[1]).toContain(`"'=HYPERLINK(""x"")"`);

    expect((await get(admin.auth, `${q}&includePhone=true`)).status).toBe(400);
    const audit = captureAudit();
    const withPhone = await get(admin.auth, `${q}&includePhone=true&reason=${encodeURIComponent('Ward survey follow-up call')}`).expect(200);
    audit.stop();
    expect(withPhone.text).toContain('"reporter_phone"');
    expect(withPhone.text).toContain('+919999911111');
    expect(audit.lines).toEqual([expect.objectContaining({ action: 'export_downloaded', extra: { dataset: 'issues', rows: 1, includePhone: true } })]);
    expect(JSON.stringify(audit.lines)).not.toContain('Ward survey');

    const mod = await as('moderator');
    expect((await get(mod.auth, q)).status).toBe(403);
    expect((await get(admin.auth, '/staff/export?dataset=issues&from=2025-01-01&to=2026-09-30')).status).toBe(400);
    await get(admin.auth, '/staff/export?dataset=issue_events&from=2026-09-01&to=2026-09-30').expect(200);
    await get(admin.auth, '/staff/export?dataset=verifications&from=2026-09-01&to=2026-09-30').expect(200);
  });
});

const SOURCE_TAG = 'rwa' as const;

describe('retired v1 pilot routes (T-10-14)', () => {
  it('404s rates and invite codes, keeps admin auth routes, leaves v1 tables untouched', async () => {
    await withLegacyWrite((tx) => tx.inviteCode.create({ data: { code: 'PILOT1', sourceTag: SOURCE_TAG, groupLabel: 'Pilot' } }));
    const { auth, admin } = await createAdmin();
    expect((await api().get(`${PREFIX}/admin/rates`).set(auth)).status).toBe(404);
    expect((await api().get(`${PREFIX}/admin/invite-codes`).set(auth)).status).toBe(404);
    expect((await api().post(`${PREFIX}/admin/invite-codes`).set(auth).send({})).status).toBe(404);
    expect((await api().post(`${PREFIX}/admin/reminders/${admin.id}/revoke`).set(auth).send({})).status).toBe(404);
    expect((await api().get(`${PREFIX}/admin/me`).set(auth)).status).toBe(200);
    expect(await prisma.inviteCode.count()).toBe(1);
  });
});
