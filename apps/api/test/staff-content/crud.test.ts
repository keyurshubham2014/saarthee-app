// T-12-10 (AC-9): staff CRUD role matrix for services, initiatives and tips; SLUG_TAKEN; audit lines.
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { prisma } from '../../src/lib/db';
import { setLinkCheckOptions } from '../../src/modules/staff-content/services.routes';
import { api } from '../helpers/app';
import { resetDb } from '../helpers/db';
import { captureStaffAudit, inHours, makeInitiative, makeService, roleUser } from '../services/helpers';

let audit: ReturnType<typeof captureStaffAudit>;
beforeEach(async () => {
  await resetDb();
  audit = captureStaffAudit();
});
afterEach(() => {
  audit.restore();
  setLinkCheckOptions({});
});

const serviceBody = (slug: string) => ({
  slug,
  category: 'certificates',
  nameEn: 'Marriage registration',
  nameGu: 'લગ્ન નોંધણી',
  department: 'Marriage Registration',
  departmentGu: 'લગ્ન નોંધણી વિભાગ',
  summaryEn: 'Register a marriage.',
  summaryGu: 'લગ્ન નોંધાવો.',
  howToEn: '1. Open the page.\n2. Book a slot.',
  howToGu: '1. પેજ ખોલો.\n2. સમય બુક કરો.',
  url: 'https://ahmedabadcity.gov.in/',
  online: false,
  visitWardOffice: true,
});

const initiativeBody = () => ({
  titleEn: 'Tree drive',
  titleGu: 'વૃક્ષારોપણ',
  descriptionEn: 'Plant saplings.',
  descriptionGu: 'રોપા વાવો.',
  type: 'tree_drive',
  organiser: 'NGO',
  organiserName: 'Green Group',
  locationTextEn: 'Park gate',
  locationTextGu: 'બગીચાનો દરવાજો',
  lat: 23.01,
  lng: 72.56,
  startsAt: inHours(48).toISOString(),
  endsAt: inHours(50).toISOString(),
  capacity: 30,
});

const tipBody = { titleEn: 'Tip', titleGu: 'ટીપ', bodyEn: 'Body', bodyGu: 'વિગત', activeFrom: '2027-04-01', activeTo: '2027-05-31' };

describe('T-12-10 staff CRUD and role guard', () => {
  it('admin creates and edits; moderator and citizen get 403; visitor 401; duplicate slug 409', async () => {
    const admin = await roleUser('admin');
    const mod = await roleUser('moderator');
    const citizen = await roleUser('citizen');

    for (const [who, status] of [[mod, 403], [citizen, 403]] as const) {
      expect((await api().post('/api/v1/staff/services').set(who.auth).send(serviceBody('x-service'))).status).toBe(status);
      expect((await api().post('/api/v1/staff/initiatives').set(who.auth).send(initiativeBody())).status).toBe(status);
      expect((await api().post('/api/v1/staff/tips').set(who.auth).send(tipBody)).status).toBe(status);
    }
    expect((await api().post('/api/v1/staff/services').send(serviceBody('x-service'))).status).toBe(401);
    expect((await api().get('/api/v1/staff/services').set(citizen.auth)).status).toBe(403);
    expect((await api().get('/api/v1/staff/services').set(mod.auth)).status).toBe(200);

    const svc = await api().post('/api/v1/staff/services').set(admin.auth).send(serviceBody('marriage-registration'));
    expect(svc.status).toBe(201);
    const dup = await api().post('/api/v1/staff/services').set(admin.auth).send(serviceBody('marriage-registration'));
    expect(dup.status).toBe(409);
    expect(dup.body.error.code).toBe('SLUG_TAKEN');
    const bad = await api().post('/api/v1/staff/services').set(admin.auth).send({ ...serviceBody('bad-one'), url: 'http://x.test', howToEn: 'just text' });
    expect(bad.status).toBe(400);
    expect(bad.body.error.details.map((d: { field: string }) => d.field).sort()).toEqual(['howToEn', 'url']);

    const patched = await api().patch(`/api/v1/staff/services/${svc.body.id}`).set(admin.auth).send({ nameEn: 'Marriage certificate', markVerified: true });
    expect(patched.status).toBe(200);
    expect(patched.body).toMatchObject({ nameEn: 'Marriage certificate', isActive: true, visitWardOffice: true });
    expect(patched.body.verifiedAt).not.toBeNull();
    expect((await api().patch(`/api/v1/staff/services/${svc.body.id}`).set(mod.auth).send({ nameEn: 'x' })).status).toBe(403);
    expect((await api().delete(`/api/v1/staff/services/${svc.body.id}`).set(admin.auth)).status).toBe(204);
    expect((await prisma.service.findUniqueOrThrow({ where: { id: svc.body.id } })).isActive).toBe(false);

    const ini = await api().post('/api/v1/staff/initiatives').set(admin.auth).send(initiativeBody());
    expect(ini.status).toBe(201);
    expect(ini.body).toMatchObject({ status: 'draft', lat: 23.01, createdById: admin.user.id });
    expect((await api().post('/api/v1/staff/initiatives').set(admin.auth).send({ ...initiativeBody(), organiser: 'AMC' })).status).toBe(400);
    const pub = await api().patch(`/api/v1/staff/initiatives/${ini.body.id}`).set(admin.auth).send({ status: 'published' });
    expect(pub.body.status).toBe('published');
    expect((await api().patch(`/api/v1/staff/initiatives/${ini.body.id}`).set(admin.auth).send({ status: 'draft' })).status).toBe(409);
    expect((await api().patch(`/api/v1/staff/initiatives/${ini.body.id}`).set(admin.auth).send({ endsAt: inHours(1).toISOString() })).status).toBe(400);

    const tip = await api().post('/api/v1/staff/tips').set(admin.auth).send({ ...tipBody, serviceSlug: 'marriage-registration' });
    expect(tip.status).toBe(201);
    expect(tip.body).toMatchObject({ activeFrom: '2027-04-01', serviceSlug: 'marriage-registration' });
    expect((await api().patch(`/api/v1/staff/tips/${tip.body.id}`).set(admin.auth).send({ activeTo: '2027-03-01' })).status).toBe(400);
    expect((await api().patch(`/api/v1/staff/tips/${tip.body.id}`).set(admin.auth).send({ serviceSlug: null })).body.serviceSlug).toBeNull();
    expect((await api().get('/api/v1/staff/tips').set(admin.auth)).body.items).toHaveLength(1);
    expect((await api().delete(`/api/v1/staff/tips/${tip.body.id}`).set(admin.auth)).status).toBe(204);
    expect((await api().delete(`/api/v1/staff/tips/${tip.body.id}`).set(admin.auth)).status).toBe(404);

    const actions = audit.lines.map((l) => l.action);
    for (const a of ['service.created', 'service.updated', 'service.deactivated', 'initiative.created', 'initiative.status_changed', 'tip.created', 'tip.updated', 'tip.deleted']) {
      expect(actions).toContain(a);
    }
    expect(audit.lines.every((l) => l.actor === admin.user.id && l.role === 'admin' && typeof l.targetId === 'string')).toBe(true);
    expect(JSON.stringify(audit.lines)).not.toMatch(/Marriage|Tree drive|Body/);
  });

  it('moderators can trigger a link re-check (limited to 10 per hour)', async () => {
    const mod = await roleUser('moderator');
    const s = await makeService({ url: 'https://fake.test/page' });
    setLinkCheckOptions({
      fetch: async () => ({ status: 404, headers: { get: () => null }, body: null }),
      sleep: async () => undefined,
    });
    const res = await api().post(`/api/v1/staff/services/${s.id}/link-check`).set(mod.auth);
    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({ linkOk: false, statusCode: 404, error: 'http_404' });
    expect((await prisma.service.findUniqueOrThrow({ where: { id: s.id } })).linkOk).toBe(false);
    for (let k = 0; k < 9; k += 1) await api().post(`/api/v1/staff/services/${s.id}/link-check`).set(mod.auth);
    expect((await api().post(`/api/v1/staff/services/${s.id}/link-check`).set(mod.auth)).status).toBe(429);
    const citizen = await roleUser();
    expect((await api().post(`/api/v1/staff/services/${s.id}/link-check`).set(citizen.auth)).status).toBe(403);
  });

  it('admin lists initiatives including drafts', async () => {
    const admin = await roleUser('admin');
    await makeInitiative({ status: 'draft' });
    await makeInitiative();
    const res = await api().get('/api/v1/staff/initiatives').set(admin.auth);
    expect(res.status).toBe(200);
    expect(res.body.items).toHaveLength(2);
  });
});
