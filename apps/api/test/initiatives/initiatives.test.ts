// T-12-06 (AC-5) list/detail and T-12-07 (AC-6) RSVP transaction, idempotency, capacity under concurrency.
import { beforeEach, describe, expect, it } from 'vitest';
import { prisma } from '../../src/lib/db';
import { api } from '../helpers/app';
import { resetDb } from '../helpers/db';
import { importFixtureWards } from '../geo/helpers';
import { inHours, makeInitiative, roleUser } from '../services/helpers';

beforeEach(resetDb);

describe('T-12-06 GET /initiatives and /initiatives/{id}', () => {
  it('lists upcoming published drives for a ward plus city-wide, sorted by start, with cursor paging', async () => {
    await importFixtureWards();
    const w1 = await prisma.ward.findFirstOrThrow({ where: { number: 1 } });
    const w2 = await prisma.ward.findFirstOrThrow({ where: { number: 2 } });
    const later = await makeInitiative({ wardId: w1.id, startsAt: inHours(72), titleEn: 'ward later' });
    const city = await makeInitiative({ wardId: null, startsAt: inHours(48), titleEn: 'city' });
    const soon = await makeInitiative({ wardId: w1.id, startsAt: inHours(24), titleEn: 'ward soon', organiser: 'AMC', sourceUrl: 'https://ahmedabadcity.gov.in/' });
    await makeInitiative({ wardId: w2.id, startsAt: inHours(30), titleEn: 'other ward' });
    const draft = await makeInitiative({ wardId: w1.id, status: 'draft' });
    await makeInitiative({ wardId: w1.id, startsAt: inHours(-48), endsAt: inHours(-46), titleEn: 'past' });

    const res = await api().get('/api/v1/initiatives').query({ ward: w1.id });
    expect(res.status).toBe(200);
    expect(res.body.items.map((i: { id: string }) => i.id)).toEqual([soon.id, city.id, later.id]);
    expect(res.body.items[0]).toMatchObject({ organiser: 'AMC', goingCount: 0, status: 'published', myRsvp: null, capacity: null });
    expect(res.body.nextCursor).toBeNull();

    const p1 = await api().get('/api/v1/initiatives').query({ limit: 2 });
    expect(p1.body.items).toHaveLength(2);
    const p2 = await api().get('/api/v1/initiatives').query({ limit: 2, cursor: p1.body.nextCursor });
    expect(p2.body.nextCursor).toBeNull();
    expect([...p1.body.items, ...p2.body.items].map((i: { titleEn: string }) => i.titleEn)).toEqual([
      'ward soon',
      'other ward',
      'city',
      'ward later',
    ]);
    expect((await api().get('/api/v1/initiatives').query({ cursor: 'bad' })).status).toBe(400);
    expect((await api().get('/api/v1/initiatives').query({ limit: 21 })).status).toBe(400);

    const d = await api().get(`/api/v1/initiatives/${soon.id}`);
    expect(d.status).toBe(200);
    expect(d.body).toMatchObject({ id: soon.id, sourceUrl: 'https://ahmedabadcity.gov.in/', descriptionEn: 'A sample drive.', lat: null, lng: null });
    expect((await api().get(`/api/v1/initiatives/${draft.id}`)).status).toBe(404);
    const admin = await roleUser('admin');
    expect((await api().get(`/api/v1/initiatives/${draft.id}`).set(admin.auth)).status).toBe(200);
  });
});

describe('T-12-07 RSVP', () => {
  it('is idempotent, respects capacity, refuses closed drives and keeps counts right', async () => {
    const i = await makeInitiative({ capacity: 2 });
    const a = await roleUser();
    const b = await roleUser();
    const c = await roleUser();
    const path = `/api/v1/initiatives/${i.id}/rsvp`;

    expect((await api().post(path)).status).toBe(401);
    expect((await api().post(path).set(a.auth)).body).toEqual({ status: 'going', goingCount: 1 });
    expect((await api().post(path).set(a.auth)).body).toEqual({ status: 'going', goingCount: 1 });
    expect((await api().get(`/api/v1/initiatives/${i.id}`).set(a.auth)).body.myRsvp).toBe('going');
    expect((await api().post(path).set(b.auth)).body.goingCount).toBe(2);
    const full = await api().post(path).set(c.auth);
    expect(full.status).toBe(409);
    expect(full.body.error.code).toBe('INITIATIVE_FULL');

    expect((await api().delete(path).set(b.auth)).body).toEqual({ status: 'cancelled', goingCount: 1 });
    expect((await api().delete(path).set(b.auth)).body).toEqual({ status: 'cancelled', goingCount: 1 });
    expect((await api().delete(path).set(c.auth)).body).toEqual({ status: 'cancelled', goingCount: 1 });
    expect((await prisma.initiative.findUniqueOrThrow({ where: { id: i.id } })).goingCount).toBe(1);

    const cancelled = await makeInitiative({ status: 'cancelled' });
    expect((await api().post(`/api/v1/initiatives/${cancelled.id}/rsvp`).set(a.auth)).body.error.code).toBe('INITIATIVE_NOT_OPEN');
    const started = await makeInitiative({ startsAt: inHours(-1), endsAt: inHours(1) });
    expect((await api().post(`/api/v1/initiatives/${started.id}/rsvp`).set(a.auth)).body.error.code).toBe('INITIATIVE_NOT_OPEN');
    expect((await api().delete(`/api/v1/initiatives/${started.id}/rsvp`).set(a.auth)).status).toBe(409);
    const draft = await makeInitiative({ status: 'draft' });
    expect((await api().post(`/api/v1/initiatives/${draft.id}/rsvp`).set(a.auth)).status).toBe(404);
    expect((await api().post('/api/v1/initiatives/00000000-0000-4000-8000-000000000000/rsvp').set(a.auth)).status).toBe(404);
  });

  it('gives the last seat to exactly one of two parallel requests', async () => {
    const i = await makeInitiative({ capacity: 1 });
    const a = await roleUser();
    const b = await roleUser();
    const path = `/api/v1/initiatives/${i.id}/rsvp`;
    const [r1, r2] = await Promise.all([api().post(path).set(a.auth), api().post(path).set(b.auth)]);
    expect([r1.status, r2.status].sort()).toEqual([200, 409]);
    expect((await prisma.initiative.findUniqueOrThrow({ where: { id: i.id } })).goingCount).toBe(1);
    expect(await prisma.rsvp.count({ where: { initiativeId: i.id, status: 'going' } })).toBe(1);
  });
});
