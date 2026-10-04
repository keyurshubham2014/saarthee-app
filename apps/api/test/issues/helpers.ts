/** TASK-05 test helpers: seeded categories + fixture wards, signed-in citizens, real JPEG uploads. */
import { randomUUID } from 'node:crypto';
import type { Prisma } from '@prisma/client';
import sharp from 'sharp';
import { seedAmcProblemTypes, seedV2Categories } from '../../prisma/seed/v2-categories';
import { prisma } from '../../src/lib/db';
import { signUserToken } from '../../src/lib/tokens';
import { api } from '../helpers/app';
import { makeUser } from '../helpers/factories';
import { importFixtureWards } from '../geo/helpers';

/** Inside fixture ward 1 "Alpha" (72.50–72.51 E, 23.00–23.01 N). */
export const INSIDE = { lat: 23.005, lng: 72.505 };
/** ≈ 500 m west of ward 1: nearest ward, confirm:true. */
export const NEAR_OUTSIDE = { lat: 23.005, lng: 72.495124 };
/** ≈ 5 km west of every ward: OUTSIDE_SERVICE_AREA. */
export const FAR_OUTSIDE = { lat: 23.005, lng: 72.451 };

export async function seedReference() {
  await seedV2Categories(prisma);
  await seedAmcProblemTypes(prisma);
  await importFixtureWards();
}

export async function citizen(data: Partial<Prisma.UserUncheckedCreateInput> = {}) {
  const user = await makeUser(data);
  const { accessToken } = signUserToken(user);
  return { user, auth: { Authorization: `Bearer ${accessToken}` } };
}

/** A real JPEG with EXIF (camera make + GPS-like comment) so stripping can be checked. */
export async function jpegWithExif(): Promise<Buffer> {
  return sharp({ create: { width: 64, height: 48, channels: 3, background: { r: 120, g: 90, b: 60 } } })
    .jpeg()
    .withExif({ IFD0: { Make: 'SaartheeTestCam', Model: 'T05' } })
    .toBuffer();
}

export async function uploadPhoto(auth: Record<string, string>, blurApplied = true): Promise<string> {
  const res = await api()
    .post('/api/v1/photos')
    .set(auth)
    .field('purpose', 'report')
    .field('blurApplied', String(blurApplied))
    .attach('photo', await jpegWithExif(), { filename: 'p.jpg', contentType: 'image/jpeg' });
  if (res.status !== 201) throw new Error(`upload failed ${res.status} ${JSON.stringify(res.body)}`);
  return res.body.photoId as string;
}

/** Owned, unattached photo row without a file (fast path for tests that do not read the bytes). */
export async function ownedPhoto(userId: string, data: Partial<Prisma.PhotoUncheckedCreateInput> = {}) {
  const p = await prisma.photo.create({
    data: {
      storageKey: `photos/2026/10/${randomUUID()}.jpg`, purpose: 'report', mimeType: 'image/jpeg', byteSize: 1000,
      widthPx: 64, heightPx: 48, sha256: randomUUID().replace(/-/g, '').padEnd(64, '0'), uploadedByUserId: userId, ...data,
    },
  });
  return p.id;
}

export function issueBody(photoIds: string[], over: Record<string, unknown> = {}) {
  return {
    clientSubmissionId: randomUUID(),
    categorySlug: 'roads',
    photoIds,
    latitude: INSIDE.lat,
    longitude: INSIDE.lng,
    gpsAccuracyM: 8,
    pinAdjusted: false,
    deviceCapturedAt: new Date().toISOString(),
    platform: 'android',
    appVersion: '2.0.0',
    ...over,
  };
}

export async function categoryId(slug: string): Promise<string> {
  return (await prisma.category.findUniqueOrThrow({ where: { slug } })).id;
}
