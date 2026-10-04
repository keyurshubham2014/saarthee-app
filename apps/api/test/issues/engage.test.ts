// T-05-06, T-05-07, T-05-11 (AC-5, AC-9): duplicate suggestions, me-too, CCRS link.
import { beforeEach, describe, expect, it } from 'vitest';
import { prisma } from '../../src/lib/db';
import { api } from '../helpers/app';
import { resetDb } from '../helpers/db';
import { makeIssue } from '../helpers/factories';
import { categoryId, citizen, INSIDE, issueBody, ownedPhoto, seedReference } from './helpers';

beforeEach(async () => {
  await resetDb();
  await seedReference();
});

/** Point `metres` north of INSIDE (1° lat ≈ 110 574 m here). */
const north = (metres: number) => ({ lat: Number((INSIDE.lat + metres / 110_574).toFixed(6)), lng: INSIDE.lng });
const DAY = 86_400_000;

describe('GET /issues/nearby (T-05-06)', () => {
  it('returns open public same-category issues within 50 m and 30 days, nearest first, without reporter data', async () => {
    const garbage = await categoryId('garbage');
    const reporter = await citizen();
    const at = (m: number) => north(m);
    const mk = (m: number, extra: Record<string, unknown> = {}) =>
      makeIssue({ categoryId: garbage, reporterId: reporter.user.id, ...at(m), createdAt: new Date(Date.now() - 10 * DAY), ...extra });
    const near30 = await mk(30);
    const near10 = await mk(10, { status: 'acknowledged' });
    await mk(20, { status: 'verified' });
    await mk(80);
    await mk(5, { visibility: 'hidden' });
    await mk(5, { createdAt: new Date(Date.now() - 31 * DAY) });
    await makeIssue({ categoryId: await categoryId('roads'), ...at(5) });
    const res = await api().get(`/api/v1/issues/nearby?lat=${INSIDE.lat}&lng=${INSIDE.lng}&category=garbage`);
    expect(res.status).toBe(200);
    expect(res.body.items.map((i: { id: string }) => i.id)).toEqual([near10.id, near30.id]);
    expect(res.body.items[1]).toMatchObject({ categorySlug: 'garbage', status: 'reported', meTooCount: 0 });
    expect(res.body.items[1].distanceM).toBeGreaterThanOrEqual(29);
    expect(res.body.items[1].distanceM).toBeLessThanOrEqual(31);
    const text = JSON.stringify(res.body);
    expect(text).not.toContain(reporter.user.id);
    expect(text).not.toMatch(/reporter|phone/i);
  });

  it('caps at 5 and validates the query', async () => {
    const garbage = await categoryId('garbage');
    for (let i = 0; i < 7; i++) await makeIssue({ categoryId: garbage, ...north(i * 3) });
    expect((await api().get(`/api/v1/issues/nearby?lat=${INSIDE.lat}&lng=${INSIDE.lng}&category=garbage`)).body.items).toHaveLength(5);
    expect((await api().get('/api/v1/issues/nearby?lat=95&lng=72.5&category=garbage')).status).toBe(400);
  });
});

describe('POST /issues/{id}/me-too (T-05-07)', () => {
  it('201 then 200 with the count; own issue and closed issue rejected', async () => {
    const owner = await citizen();
    const other = await citizen();
    const issue = await makeIssue({ reporterId: owner.user.id, categoryId: await categoryId('garbage') });
    const first = await api().post(`/api/v1/issues/${issue.id}/me-too`).set(other.auth);
    expect(first.status).toBe(201);
    expect(first.body).toEqual({ meTooCount: 1 });
    const again = await api().post(`/api/v1/issues/${issue.id}/me-too`).set(other.auth);
    expect(again.status).toBe(200);
    expect(again.body).toEqual({ meTooCount: 1 });
    expect((await prisma.issue.findUniqueOrThrow({ where: { id: issue.id } })).meTooCount).toBe(1);
    const own = await api().post(`/api/v1/issues/${issue.id}/me-too`).set(owner.auth);
    expect(own.status).toBe(409);
    expect(own.body.error.code).toBe('OWN_ISSUE');
    const closed = await makeIssue({ status: 'verified' });
    const c = await api().post(`/api/v1/issues/${closed.id}/me-too`).set(other.auth);
    expect(c.status).toBe(409);
    expect(c.body.error.code).toBe('ISSUE_NOT_OPEN');
    expect((await api().post(`/api/v1/issues/${issue.id}/me-too`)).status).toBe(401);
  });
});

describe('POST /issues/{id}/ccrs (T-05-11)', () => {
  it('normalises, records ccrs_linked, moves reported → sent; same 200, different 409, non-reporter 403', async () => {
    const a = await citizen();
    const created = await api().post('/api/v1/issues').set(a.auth).send(issueBody([await ownedPhoto(a.user.id)]));
    const id = created.body.issue.id as string;
    const res = await api().post(`/api/v1/issues/${id}/ccrs`).set(a.auth).send({ ccrsNumber: 'amc-2026 1234', filedVia: 'whatsapp' });
    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({ ccrsNumber: 'AMC20261234', status: 'sent' });
    expect(res.body.ccrsFiledAt).toBeTruthy();
    const events = await prisma.issueEvent.findMany({ where: { issueId: id }, orderBy: { createdAt: 'asc' } });
    expect(events.map((e) => `${e.type}:${e.note ?? ''}:${e.toStatus ?? ''}`)).toEqual(
      expect.arrayContaining(['ccrs_linked:via:whatsapp:', 'status_change::sent']),
    );
    expect((await api().post(`/api/v1/issues/${id}/ccrs`).set(a.auth).send({ ccrsNumber: 'AMC-2026-1234', filedVia: 'web' })).status).toBe(200);
    const diff = await api().post(`/api/v1/issues/${id}/ccrs`).set(a.auth).send({ ccrsNumber: 'AMC-9999', filedVia: 'web' });
    expect(diff.status).toBe(409);
    expect(diff.body.error.code).toBe('CCRS_ALREADY_LINKED');
    const b = await citizen();
    const forbidden = await api().post(`/api/v1/issues/${id}/ccrs`).set(b.auth).send({ ccrsNumber: 'AMC-1', filedVia: 'web' });
    expect(forbidden.status).toBe(403);
    expect(forbidden.body.error.code).toBe('FORBIDDEN');
    const blank = await api().post(`/api/v1/issues/${id}/ccrs`).set(a.auth).send({ ccrsNumber: ' - ', filedVia: 'web' });
    expect(blank.status).toBe(400);
  });
});
