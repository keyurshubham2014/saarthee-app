import { randomUUID } from 'node:crypto';
import type { Prisma } from '@prisma/client';
import { prisma, withLegacyWrite } from '../../src/lib/db';

let seq = 0;
const next = () => ++seq;

/** Photo row only (no file on disk): enough for FK/constraint tests; deleting a missing file succeeds. */
export async function makePhoto(data: Partial<Prisma.PhotoUncheckedCreateInput> = {}) {
  return prisma.photo.create({
    data: {
      storageKey: `photos/2026/10/${randomUUID()}.jpg`,
      purpose: 'report',
      mimeType: 'image/jpeg',
      byteSize: 1000,
      widthPx: 640,
      heightPx: 480,
      sha256: randomUUID().replace(/-/g, '').padEnd(64, '0'),
      attachedAt: new Date(),
      ...data,
    },
  });
}

/** Citizen with a fictional +9190000000NN-style phone (unique per call) and Firebase uid. */
export async function makeUser(data: Partial<Prisma.UserUncheckedCreateInput> = {}) {
  const n = next();
  return prisma.user.create({
    data: {
      phoneE164: `+9190001${String(n).padStart(5, '0')}`,
      firebaseUid: `test-uid-${n}-${randomUUID().slice(0, 8)}`,
      ...data,
    },
  });
}

export async function makeCategory(data: Partial<Prisma.CategoryUncheckedCreateInput> = {}) {
  const n = next();
  const slug = data.slug ?? `tc_${n.toString(36).replace(/[0-9]/g, (d) => 'abcdefghij'[Number(d)]!)}`;
  return prisma.category.create({
    data: {
      slug,
      nameEn: `Category ${n}`,
      nameGu: `શ્રેણી ${n}`,
      icon: slug,
      colourToken: `cat_${slug}`,
      slaDays: 7,
      sortOrder: n,
      ...data,
    },
  });
}

/** Issue at Paldi by default; location is filled by the database trigger. */
export async function makeIssue(data: Partial<Prisma.IssueUncheckedCreateInput> = {}) {
  const categoryId = data.categoryId ?? (await makeCategory()).id;
  return prisma.issue.create({
    data: {
      clientSubmissionId: randomUUID(),
      title: 'Test issue',
      lat: 23.012345,
      lng: 72.561234,
      slaDueAt: new Date(Date.now() + 7 * 86_400_000),
      ...data,
      categoryId,
    },
  });
}

/** v1 CCRS category, written through the legacy bypass (v1 tables are read-only). */
export async function makeCcrsCategory(name: string) {
  return withLegacyWrite((tx) => tx.ccrsCategory.create({ data: { name, sortOrder: next() } }));
}

/** v1 complaint (+ its photo), written through the legacy bypass. */
export async function makeComplaint(data: Partial<Prisma.ComplaintUncheckedCreateInput> & { categoryId: string }) {
  const photo = await makePhoto();
  const n = next();
  return withLegacyWrite((tx) =>
    tx.complaint.create({
      data: {
        clientSubmissionId: randomUUID(),
        ccrsNumberRaw: `AMC-TEST-${n}`,
        ccrsNumberNormalized: `AMCTEST${n}`,
        photoId: photo.id,
        latitude: 23.0225,
        longitude: 72.5714,
        deviceCapturedAt: new Date(),
        phoneE164: '+919000000099',
        consentGivenAt: new Date(),
        consentTextVersion: 'v1',
        appPlatform: 'android',
        appVersion: 'test',
        ...data,
      },
    }),
  );
}
