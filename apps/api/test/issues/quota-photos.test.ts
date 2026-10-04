// T-05-10, T-05-12, T-05-13 (AC-8, AC-10, AC-11): hidden photo access, per-user quotas, owned photo uploads.
import { buffer } from 'node:stream/consumers';
import sharp from 'sharp';
import { beforeEach, describe, expect, it } from 'vitest';
import { prisma } from '../../src/lib/db';
import { storage } from '../../src/lib/storage';
import { assertDailyQuota, quotaRetryAfter, quotaUsage } from '../../src/lib/quota';
import { clearMediaCache } from '../../src/modules/photos/media.service';
import { api } from '../helpers/app';
import { resetDb } from '../helpers/db';
import { makeIssue } from '../helpers/factories';
import { citizen, issueBody, ownedPhoto, seedReference, uploadPhoto } from './helpers';

beforeEach(async () => {
  await resetDb();
  clearMediaCache();
  await seedReference();
});

const HOUR = 3_600_000;

describe('POST /photos (T-05-13)', () => {
  it('401 without a session; stores owner and blurApplied; EXIF stripped', async () => {
    const anon = await api().post('/api/v1/photos').field('purpose', 'report').attach('photo', Buffer.from([0xff, 0xd8, 0xff, 0x00]), 'p.jpg');
    expect(anon.status).toBe(401);
    expect(anon.body.error.code).toBe('AUTH_REQUIRED');
    const a = await citizen();
    const id = await uploadPhoto(a.auth, true);
    const row = await prisma.photo.findUniqueOrThrow({ where: { id } });
    expect(row).toMatchObject({ uploadedByUserId: a.user.id, blurApplied: true, attachedAt: null, purpose: 'report' });
    const stored = await buffer(await storage.open(row.storageKey));
    const meta = await sharp(stored).metadata();
    expect(meta.exif).toBeUndefined();
    expect(stored.includes(Buffer.from('SaartheeTestCam'))).toBe(false);
    const noBlur = await uploadPhoto(a.auth, false);
    expect((await prisma.photo.findUniqueOrThrow({ where: { id: noBlur } })).blurApplied).toBe(false);
  });
});

describe('GET /media/photos/{id} (T-05-10)', () => {
  it('public issue photo for anyone; hidden (sensitive) photo 404 publicly, 200 for the owner', async () => {
    const a = await citizen();
    const pub = await api().post('/api/v1/issues').set(a.auth).send(issueBody([await uploadPhoto(a.auth)]));
    const hid = await api().post('/api/v1/issues').set(a.auth).send(issueBody([await uploadPhoto(a.auth)], { categorySlug: 'building', structuredReason: 'unsafe' }));
    expect(hid.body.issue.visibility).toBe('hidden');
    const photoOf = async (issueId: string) => (await prisma.issuePhoto.findFirstOrThrow({ where: { issueId } })).photoId;
    const pubPhoto = await photoOf(pub.body.issue.id);
    const hidPhoto = await photoOf(hid.body.issue.id);
    const ok = await api().get(`/api/v1/media/photos/${pubPhoto}?w=320`);
    expect(ok.status).toBe(200);
    expect(ok.headers['content-type']).toBe('image/jpeg');
    expect((await api().get(`/api/v1/media/photos/${hidPhoto}`)).status).toBe(404);
    const other = await citizen();
    expect((await api().get(`/api/v1/media/photos/${hidPhoto}`).set(other.auth)).status).toBe(404);
    expect((await api().get(`/api/v1/media/photos/${hidPhoto}`).set(a.auth)).status).toBe(200);
    const mod = await citizen({ role: 'moderator' });
    expect((await api().get(`/api/v1/media/photos/${hidPhoto}`).set(mod.auth)).status).toBe(200);
    expect((await api().get(`/api/v1/media/photos/${pubPhoto}?w=77`)).status).toBe(400);
  });
});

describe('quota helper (T-05-12)', () => {
  it('11th issue in 24 h → 429 issues_per_day with a correct Retry-After', async () => {
    const a = await citizen();
    const oldest = new Date(Date.now() - 20 * HOUR);
    for (let i = 0; i < 10; i++) await makeIssue({ reporterId: a.user.id, createdAt: i === 0 ? oldest : new Date(Date.now() - HOUR) });
    const res = await api().post('/api/v1/issues').set(a.auth).send(issueBody([await ownedPhoto(a.user.id)]));
    expect(res.status).toBe(429);
    expect(res.body.error).toMatchObject({ code: 'RATE_LIMITED', details: [{ field: 'quota', issue: 'issues_per_day' }] });
    const retry = Number(res.headers['retry-after']);
    expect(retry).toBeGreaterThan(4 * 3600 - 60);
    expect(retry).toBeLessThanOrEqual(4 * 3600);
  });

  it('reports over-limit for me_too, verifications, photos (and messages when that table exists)', async () => {
    const a = await citizen();
    const roads = (await prisma.category.findUniqueOrThrow({ where: { slug: 'roads' } })).id;
    const issues = await Promise.all(Array.from({ length: 100 }, () => makeIssue({ categoryId: roads })));
    await prisma.meToo.createMany({ data: issues.map((i) => ({ issueId: i.id, userId: a.user.id })) });
    await expect(assertDailyQuota(a.user.id, 'me_too')).rejects.toMatchObject({ code: 'RATE_LIMITED', details: [{ issue: 'me_too_per_day' }] });
    const today = new Date();
    await prisma.issueVerification.createMany({ data: issues.slice(0, 20).map((i) => ({ issueId: i.id, userId: a.user.id, answer: 'fixed' as const, createdDay: today })) });
    await expect(assertDailyQuota(a.user.id, 'verifications')).rejects.toMatchObject({ details: [{ issue: 'verifications_per_day' }] });
    for (let i = 0; i < 40; i++) await ownedPhoto(a.user.id);
    await expect(assertDailyQuota(a.user.id, 'photos')).rejects.toMatchObject({ details: [{ issue: 'photos_per_day' }] });
    await expect(assertDailyQuota(a.user.id, 'issues')).resolves.toBeUndefined();
    const hasMessages = (await prisma.$queryRaw<{ ok: boolean }[]>`SELECT to_regclass('public.rep_messages') IS NOT NULL AS ok`)[0]!.ok;
    if (!hasMessages) await expect(assertDailyQuota(a.user.id, 'messages', { representativeId: a.user.id })).resolves.toBeUndefined();
    // Rows older than 24 h are not counted.
    const b = await citizen();
    for (let i = 0; i < 10; i++) await makeIssue({ reporterId: b.user.id, createdAt: new Date(Date.now() - 25 * HOUR) });
    expect((await quotaUsage(b.user.id, 'issues')).count).toBe(0);
  });

  it('pure Retry-After: messages limit 5, oldest 2 h ago → 22 h', () => {
    const now = new Date('2026-10-04T12:00:00Z');
    expect(quotaRetryAfter({ count: 4, oldest: new Date(now.getTime() - 2 * HOUR) }, 5, now)).toBeNull();
    expect(quotaRetryAfter({ count: 5, oldest: new Date(now.getTime() - 2 * HOUR) }, 5, now)).toBe(22 * 3600);
  });
});
