// T-05-04, T-05-05, T-05-08, T-05-09, T-05-15, T-05-16 (AC-3, AC-4, AC-6, AC-8): POST /issues.
import { randomUUID } from 'node:crypto';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { prisma } from '../../src/lib/db';
import { createIssueHooks } from '../../src/modules/issues/issues.service';
import { api } from '../helpers/app';
import { resetDb } from '../helpers/db';
import { citizen, FAR_OUTSIDE, INSIDE, issueBody, NEAR_OUTSIDE, ownedPhoto, seedReference } from './helpers';

beforeEach(async () => {
  await resetDb();
  await seedReference();
});
afterEach(() => {
  delete createIssueHooks.afterInsert;
});

const post = (auth: Record<string, string>, body: unknown) => api().post('/api/v1/issues').set(auth).send(body as object);

describe('POST /issues happy path (T-05-04)', () => {
  it('stores ward/zone, SLA, opening event, reporter follow and attaches photos', async () => {
    const a = await citizen();
    const photo = await ownedPhoto(a.user.id);
    const before = Date.now();
    const res = await post(a.auth, issueBody([photo]));
    expect(res.status).toBe(201);
    const ward = await prisma.ward.findFirstOrThrow({ where: { number: 1 } });
    expect(res.body.issue).toMatchObject({ status: 'reported', wardId: ward.id, wardNameEn: ward.nameEn, visibility: 'public' });
    expect(res.body.amcHandoff.problemTypes[0]).toMatchObject({ problemEn: 'Road-Repair Require', isPrimary: true });
    const issue = await prisma.issue.findUniqueOrThrow({ where: { id: res.body.issue.id }, include: { photos: true, events: true, follows: true } });
    expect(issue).toMatchObject({ reporterId: a.user.id, zoneId: ward.zoneId, followerCount: 1, meTooCount: 0, isSensitive: false });
    expect(issue.title).toBe(`Roads & potholes · ${ward.nameEn}`);
    const slaDays = (issue.slaDueAt.getTime() - issue.createdAt.getTime()) / 86_400_000;
    expect(slaDays).toBeCloseTo(7, 2);
    expect(issue.createdAt.getTime()).toBeGreaterThanOrEqual(before - 1000);
    expect(issue.photos).toEqual([expect.objectContaining({ photoId: photo, kind: 'report', position: 0 })]);
    expect(issue.events).toEqual([expect.objectContaining({ type: 'status_change', fromStatus: null, toStatus: 'reported', actorRole: 'citizen' })]);
    expect(issue.follows.map((f) => f.userId)).toEqual([a.user.id]);
    expect((await prisma.photo.findUniqueOrThrow({ where: { id: photo } })).attachedAt).not.toBeNull();
    const [loc] = await prisma.$queryRaw<{ lat: number }[]>`SELECT ST_Y(location::geometry) AS lat FROM issues WHERE id = ${issue.id}::uuid`;
    expect(Number(loc!.lat)).toBeCloseTo(INSIDE.lat, 5);
  });

  it('records pinAdjusted and the distance from the fix in the event note', async () => {
    const a = await citizen();
    const res = await post(a.auth, issueBody([await ownedPhoto(a.user.id)], { pinAdjusted: true, fixLatitude: INSIDE.lat + 0.00027, fixLongitude: INSIDE.lng }));
    expect(res.status).toBe(201);
    const ev = await prisma.issueEvent.findFirstOrThrow({ where: { issueId: res.body.issue.id } });
    expect(ev.note).toMatch(/^pinAdjusted; pinDistanceFromFixM=3\d$/);
  });
});

describe('ward confirmation (T-05-05)', () => {
  it('near a ward needs confirmedWardId; with it → 201; 5 km out → OUTSIDE_SERVICE_AREA', async () => {
    const a = await citizen();
    const near = await post(a.auth, issueBody([await ownedPhoto(a.user.id)], { latitude: NEAR_OUTSIDE.lat, longitude: NEAR_OUTSIDE.lng }));
    expect(near.status).toBe(422);
    expect(near.body.error.code).toBe('WARD_CONFIRMATION_REQUIRED');
    const suggested = near.body.error.details[0].suggestedWardId as string;
    expect(near.body.error.details[0].field).toBe('confirmedWardId');
    const ok = await post(a.auth, issueBody([await ownedPhoto(a.user.id)], { latitude: NEAR_OUTSIDE.lat, longitude: NEAR_OUTSIDE.lng, confirmedWardId: suggested, pinAdjusted: true }));
    expect(ok.status).toBe(201);
    expect(ok.body.issue.wardId).toBe(suggested);
    const far = await post(a.auth, issueBody([await ownedPhoto(a.user.id)], { latitude: FAR_OUTSIDE.lat, longitude: FAR_OUTSIDE.lng }));
    expect(far.status).toBe(422);
    expect(far.body.error).toMatchObject({ code: 'OUTSIDE_SERVICE_AREA', message: "This place is outside Ahmedabad's wards. Saarthee can only take reports inside the city." });
  });
});

describe('idempotency (T-05-08)', () => {
  it('repeat → 200 same id; 8 concurrent → one 201 and one row; another user → 409', async () => {
    const a = await citizen();
    const body = issueBody([await ownedPhoto(a.user.id)]);
    const first = await post(a.auth, body);
    expect(first.status).toBe(201);
    const again = await post(a.auth, body);
    expect(again.status).toBe(200);
    expect(again.body.issue.id).toBe(first.body.issue.id);

    const conc = issueBody([await ownedPhoto(a.user.id)]);
    const results = await Promise.all(Array.from({ length: 8 }, () => post(a.auth, conc)));
    expect(results.map((r) => r.status).sort()).toEqual([200, 200, 200, 200, 200, 200, 200, 201]);
    expect(new Set(results.map((r) => r.body.issue.id)).size).toBe(1);
    expect(await prisma.issue.count({ where: { clientSubmissionId: conc.clientSubmissionId } })).toBe(1);

    const b = await citizen();
    const reuse = await post(b.auth, { ...body, photoIds: [await ownedPhoto(b.user.id)] });
    expect(reuse.status).toBe(409);
    expect(reuse.body.error.code).toBe('IDEMPOTENCY_KEY_REUSED');
  });
});

describe('business-rule rejections (T-05-09)', () => {
  it('rejects unusable photos, inactive category, sensitive description, future clock and photo counts', async () => {
    const a = await citizen();
    const b = await citizen();
    const code = async (body: unknown) => {
      const r = await post(a.auth, body);
      return `${r.status} ${r.body.error?.code}`;
    };
    expect(await code(issueBody([await ownedPhoto(a.user.id, { uploadedAt: new Date(Date.now() - 25 * 3_600_000) })]))).toBe('422 PHOTO_UNUSABLE');
    expect(await code(issueBody([await ownedPhoto(b.user.id)]))).toBe('422 PHOTO_UNUSABLE');
    expect(await code(issueBody([await ownedPhoto(a.user.id, { attachedAt: new Date() })]))).toBe('422 PHOTO_UNUSABLE');
    await prisma.category.update({ where: { slug: 'water' }, data: { isActive: false } });
    expect(await code(issueBody([await ownedPhoto(a.user.id)], { categorySlug: 'water' }))).toBe('422 CATEGORY_INACTIVE');
    expect(await code(issueBody([await ownedPhoto(a.user.id)], { categorySlug: 'encroachment', description: 'My neighbour', structuredReason: 'road' }))).toBe('400 VALIDATION_FAILED');
    expect(await code(issueBody([await ownedPhoto(a.user.id)], { categorySlug: 'encroachment' }))).toBe('400 VALIDATION_FAILED');
    expect(await code(issueBody([await ownedPhoto(a.user.id)], { deviceCapturedAt: new Date(Date.now() + 15 * 60_000).toISOString() }))).toBe('400 VALIDATION_FAILED');
    expect(await code(issueBody([]))).toBe('400 VALIDATION_FAILED');
    const four = await Promise.all([1, 2, 3, 4].map(() => ownedPhoto(a.user.id)));
    expect(await code(issueBody(four))).toBe('400 VALIDATION_FAILED');
    expect(await code({ ...issueBody([await ownedPhoto(a.user.id)]), clientSubmissionId: 'not-a-uuid' })).toBe('400 VALIDATION_FAILED');
    expect(await prisma.issue.count()).toBe(0);
  });

  it('sensitive category with a structured reason is stored hidden', async () => {
    const a = await citizen();
    const res = await post(a.auth, issueBody([await ownedPhoto(a.user.id)], { categorySlug: 'encroachment', structuredReason: 'footpath' }));
    expect(res.status).toBe(201);
    expect(res.body.issue.visibility).toBe('hidden');
    const issue = await prisma.issue.findUniqueOrThrow({ where: { id: res.body.issue.id } });
    expect(issue).toMatchObject({ isSensitive: true, description: 'Blocking the footpath' });
  });
});

describe('auth and account status (T-05-15)', () => {
  it('401 without a session, 403 ACCOUNT_SUSPENDED for a suspended citizen', async () => {
    expect((await api().post('/api/v1/issues').send(issueBody([randomUUID()]))).status).toBe(401);
    const s = await citizen({ status: 'suspended' });
    const res = await post(s.auth, issueBody([await ownedPhoto(s.user.id)]));
    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('ACCOUNT_SUSPENDED');
  });
});

describe('transaction rollback (T-05-16)', () => {
  it('a failure after the insert leaves no issue and the photo unattached', async () => {
    const a = await citizen();
    const photo = await ownedPhoto(a.user.id);
    createIssueHooks.afterInsert = async () => {
      throw new Error('forced failure');
    };
    const res = await post(a.auth, issueBody([photo]));
    expect(res.status).toBe(500);
    expect(await prisma.issue.count()).toBe(0);
    expect(await prisma.issueEvent.count()).toBe(0);
    expect((await prisma.photo.findUniqueOrThrow({ where: { id: photo } })).attachedAt).toBeNull();
  });
});
