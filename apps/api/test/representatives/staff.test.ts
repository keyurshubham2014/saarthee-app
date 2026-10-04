// T-09-09: staff CRUD + mapping + role checks (AC-8).
import { beforeEach, describe, expect, it } from 'vitest';
import { prisma } from '../../src/lib/db';
import { captureLogs } from '../../src/lib/logger';
import { api } from '../helpers/app';
import { resetDb } from '../helpers/db';
import { fixtureWards, makeAc, makeRep, SRC, userWithToken } from './helpers';

let wards: Map<number, string>;
beforeEach(async () => {
  await resetDb();
  wards = await fixtureWards();
});

const body = {
  nameEn: 'New Person',
  nameGu: 'નવી વ્યક્તિ',
  role: 'corporator',
  partyText: 'Test Party',
  termStart: '2026-03-01',
  termEnd: '2031-02-28',
  wardNumber: 1,
  officePhone: '079 2658 1234',
  publicEmail: 'New.Person@Example.org',
  sourceUrl: SRC,
  lastVerifiedAt: '2026-09-12',
};

describe('staff representatives (T-09-09)', () => {
  it('admin creates, edits party, deactivates (gone from My Ward), mobile → 400, maps ward to 2 ACs; audited', async () => {
    const admin = await userWithToken({ role: 'admin' });
    const logs = captureLogs();
    const created = await api().post('/api/v1/staff/representatives').set(admin.auth).send(body);
    expect(created.status).toBe(201);
    expect(created.body).toMatchObject({ officePhone: '+917926581234', publicEmail: 'new.person@example.org', wardNumber: 1, needsRecheck: false });
    const id = created.body.id as string;

    const dup = await api().post('/api/v1/staff/representatives').set(admin.auth).send(body);
    expect(dup.status).toBe(409);
    expect(dup.body.error.code).toBe('REP_DUPLICATE');

    const party = await api().patch(`/api/v1/staff/representatives/${id}`).set(admin.auth).send({ partyText: 'Independent' });
    expect(party.status).toBe(200);
    expect(party.body.partyText).toBe('Independent');

    const mobile = await api().patch(`/api/v1/staff/representatives/${id}`).set(admin.auth).send({ officePhone: '98250 12345' });
    expect(mobile.status).toBe(400);
    expect(mobile.body.error.code).toBe('REP_PERSONAL_NUMBER');
    expect((await prisma.representative.findUniqueOrThrow({ where: { id } })).publicPhone).toBe('+917926581234');

    const other = await makeRep({ nameEn: 'Other Person' }, [{ wardId: wards.get(1)! }]);
    expect((await api().delete(`/api/v1/staff/representatives/${other.id}`).set(admin.auth)).status).toBe(200);
    const ward = await api().get(`/api/v1/wards/${wards.get(1)}/representatives`);
    expect(ward.body.corporators.map((r: { id: string }) => r.id)).toEqual([id]);

    const ac1 = await makeAc(44);
    const ac2 = await makeAc(45);
    const map = await api()
      .put(`/api/v1/staff/wards/${wards.get(1)}/constituencies`)
      .set(admin.auth)
      .send({ items: [{ acId: ac1.id, sourceUrl: SRC }, { acId: ac2.id, sourceUrl: SRC }] });
    expect(map.status).toBe(200);
    expect((await api().get(`/api/v1/wards/${wards.get(1)}/representatives`)).body.ward.assemblyConstituencyCount).toBe(2);
    const consts = await api().get('/api/v1/staff/constituencies').set(admin.auth);
    expect(consts.body.items[0]).toMatchObject({ number: 44, wardNumbers: [1] });
    logs.stop();
    const audit = logs.lines.filter((l) => l.includes('staff_action')).map((l) => JSON.parse(l).action);
    expect(audit).toEqual(['rep_created', 'rep_updated', 'rep_deactivated', 'ward_constituencies_updated']);
    expect(logs.lines.join('\n')).not.toContain('98250');
  });

  it('enforces the 4-seat cap and validation details', async () => {
    const admin = await userWithToken({ role: 'admin' });
    for (let i = 0; i < 4; i++) await makeRep({}, [{ wardId: wards.get(2)! }]);
    const r = await api().post('/api/v1/staff/representatives').set(admin.auth).send({ ...body, wardNumber: 2 });
    expect(r.status).toBe(400);
    expect(r.body.error.details[0]).toMatchObject({ field: 'wardNumber' });
    const bad = await api().post('/api/v1/staff/representatives').set(admin.auth).send({ ...body, sourceUrl: 'http://x.org' });
    expect(bad.status).toBe(400);
    expect(bad.body.error.details[0].field).toBe('source_url');
  });

  it('list flags entries older than 180 days and filters by ward and role', async () => {
    const mod = await userWithToken({ role: 'moderator' });
    await makeRep({ nameEn: 'Stale Person', lastVerifiedAt: new Date('2025-01-01') }, [{ wardId: wards.get(1)! }]);
    await makeRep({ nameEn: 'Fresh Person', lastVerifiedAt: new Date() }, [{ wardId: wards.get(2)! }]);
    const all = await api().get('/api/v1/staff/representatives').set(mod.auth);
    expect(all.status).toBe(200);
    const stale = all.body.items.find((i: { nameEn: string }) => i.nameEn === 'Stale Person');
    expect(stale.needsRecheck).toBe(true);
    const w2 = await api().get('/api/v1/staff/representatives?ward=2&role=corporator').set(mod.auth);
    expect(w2.body.items.map((i: { nameEn: string }) => i.nameEn)).toEqual(['Fresh Person']);
  });

  it('moderator reads only (403 on writes); citizen 403; signed-out 401', async () => {
    const mod = await userWithToken({ role: 'moderator' });
    const cit = await userWithToken();
    const rep = await makeRep({});
    expect((await api().patch(`/api/v1/staff/representatives/${rep.id}`).set(mod.auth).send({ partyText: 'X' })).status).toBe(403);
    expect((await api().post('/api/v1/staff/representatives').set(mod.auth).send(body)).status).toBe(403);
    expect((await api().get('/api/v1/staff/representatives').set(cit.auth)).status).toBe(403);
    expect((await api().get('/api/v1/staff/constituencies').set(cit.auth)).status).toBe(403);
    expect((await api().get('/api/v1/staff/representatives')).status).toBe(401);
  });
});
