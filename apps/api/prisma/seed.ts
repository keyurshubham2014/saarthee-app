/* Development seed (04 §8). Reference data is idempotent; the sample set is dev-only and guarded. */
import { createHash, randomBytes, randomUUID } from 'node:crypto';
import { PrismaClient, type SourceTag, type VerificationResult } from '@prisma/client';
import { hashPassword } from '../src/lib/password';
import { makePlaceholderJpeg } from './seed-photo';

const prisma = new PrismaClient();
const DAY = 86_400_000;
const ago = (days: number, extraMs = 0) => new Date(Date.now() - days * DAY + extraMs);

function fail(msg: string): never {
  console.error(`Seed refused: ${msg}`);
  process.exit(1);
}

async function main() {
  if (process.env.APP_ENV !== 'development') fail('APP_ENV must be development.');
  const email = process.env.SEED_ADMIN_EMAIL?.trim().toLowerCase();
  const password = process.env.SEED_ADMIN_PASSWORD;
  const photoDir = process.env.PHOTO_STORAGE_DIR;
  if (!email || !password) fail('SEED_ADMIN_EMAIL and SEED_ADMIN_PASSWORD must be set.');
  if (!photoDir) fail('PHOTO_STORAGE_DIR must be set.');

  const real = await prisma.complaint.count({ where: { appVersion: { not: 'seed' } } });
  if (real > 0) fail('non-seed complaints exist (real pilot data?). Nothing changed.');

  // --- reference data (idempotent upserts) ---
  const admin = await prisma.adminUser.upsert({
    where: { email },
    update: {},
    create: { email, passwordHash: await hashPassword(password), displayName: 'Dev Admin' },
  });
  const codes: [string, SourceTag, string][] = [
    ['RWATEST01', 'rwa', 'Test RWA — Navrangpura'],
    ['ACTTEST01', 'activist', 'Test activist group'],
    ['SOCTEST01', 'social', 'Test social media post'],
    ['NETTEST01', 'network', 'Test personal network'],
  ];
  const inviteIds: Record<string, string> = {};
  for (const [code, sourceTag, groupLabel] of codes) {
    const row = await prisma.inviteCode.upsert({
      where: { code },
      update: {},
      create: { code, sourceTag, groupLabel, createdBy: admin.id },
    });
    inviteIds[sourceTag] = row.id;
  }
  const cats = ['Pothole or damaged road', 'Garbage and cleanliness', 'Streetlight', 'Drainage', 'Water supply', 'Other'];
  const catIds: string[] = [];
  for (const [i, name] of cats.entries()) {
    const row = await prisma.ccrsCategory.upsert({ where: { name }, update: {}, create: { name, sortOrder: (i + 1) * 10 } });
    catIds.push(row.id);
  }

  // --- sample set (only when no complaints yet) ---
  if ((await prisma.complaint.count()) > 0) {
    console.log('Seed: reference data ensured; sample complaints already present, skipped.');
    return;
  }

  let hue = 1;
  type V = { result: VerificationResult; daysAgo: number; note?: string; samePhoto?: boolean };
  type Spec = {
    n: number;
    source: SourceTag;
    createdDaysAgo: number;
    reminderDaysAgo?: number;
    verifications?: V[];
    excluded?: boolean;
    ccrs: string;
  };
  const specs: Spec[] = [
    { n: 1, source: 'rwa', createdDaysAgo: 10, ccrs: 'AMC-2026-0001' },
    { n: 2, source: 'rwa', createdDaysAgo: 2, ccrs: 'AMC-2026-0002' },
    { n: 3, source: 'rwa', createdDaysAgo: 15, reminderDaysAgo: 8, ccrs: 'AMC-2026-0003' },
    { n: 4, source: 'rwa', createdDaysAgo: 20, reminderDaysAgo: 12, verifications: [{ result: 'fixed', daysAgo: 11 }], ccrs: 'AMC-2026-0004' },
    { n: 5, source: 'rwa', createdDaysAgo: 20, reminderDaysAgo: 12, verifications: [{ result: 'not_fixed', daysAgo: 11, note: 'Still broken near the gate.' }], ccrs: 'AMC-2026-0005' },
    { n: 6, source: 'activist', createdDaysAgo: 25, reminderDaysAgo: 14, verifications: [{ result: 'fixed', daysAgo: 13 }, { result: 'not_fixed', daysAgo: 5 }], ccrs: 'AMC-2026-0006' },
    { n: 7, source: 'activist', createdDaysAgo: 12, reminderDaysAgo: 2, ccrs: 'AMC-2026-0007' },
    { n: 8, source: 'activist', createdDaysAgo: 18, reminderDaysAgo: 10, verifications: [{ result: 'not_fixed', daysAgo: 9 }], excluded: true, ccrs: 'AMC-2026-0008' },
    { n: 9, source: 'social', createdDaysAgo: 16, reminderDaysAgo: 9, verifications: [{ result: 'fixed', daysAgo: 8, samePhoto: true }], ccrs: 'AMC-2026-0009' },
    { n: 10, source: 'network', createdDaysAgo: 16, reminderDaysAgo: 9, verifications: [{ result: 'not_fixed', daysAgo: 8 }], ccrs: 'AMC-2026-0010' },
    { n: 11, source: 'unknown', createdDaysAgo: 9, ccrs: 'amc 2026 0001' },
  ];

  const seen = new Set<string>();
  for (const s of specs) {
    const lat = 23.0225 + s.n * 0.0011;
    const lng = 72.5714 + s.n * 0.0013;
    const created = ago(s.createdDaysAgo);
    const reportPhoto = await makePlaceholderJpeg(photoDir, hue++);
    const photo = await prisma.photo.create({
      data: {
        storageKey: reportPhoto.key, purpose: 'report', mimeType: 'image/jpeg', byteSize: reportPhoto.byteSize,
        widthPx: reportPhoto.width, heightPx: reportPhoto.height, sha256: reportPhoto.sha256,
        uploadedAt: created, attachedAt: created,
      },
    });
    const normalized = s.ccrs.toUpperCase().replace(/[\s-]/g, '');
    const complaint = await prisma.complaint.create({
      data: {
        clientSubmissionId: randomUUID(),
        inviteCodeId: s.source === 'unknown' ? null : inviteIds[s.source],
        sourceTag: s.source,
        categoryId: catIds[s.n % catIds.length]!,
        ccrsNumberRaw: s.ccrs,
        ccrsNumberNormalized: normalized,
        ccrsDuplicateFlag: seen.has(normalized),
        photoId: photo.id,
        latitude: lat, longitude: lng, gpsAccuracyM: 8,
        deviceCapturedAt: created,
        // Invented test numbers in the valid +91 6-9 range; not real people.
        phoneE164: `+9190000000${String(s.n).padStart(2, '0')}`,
        consentGivenAt: created, consentTextVersion: 'v1',
        appPlatform: 'android', appVersion: 'seed',
        isExcluded: !!s.excluded,
        exclusionReason: s.excluded ? 'test' : null,
        exclusionNote: s.excluded ? 'Seeded test record' : null,
        excludedBy: s.excluded ? admin.id : null,
        excludedAt: s.excluded ? ago(1) : null,
        createdAt: created,
      },
    });
    seen.add(normalized);
    if (s.reminderDaysAgo === undefined) continue;
    const reminder = await prisma.reminder.create({
      data: {
        complaintId: complaint.id,
        // Hash of a random token that is discarded and never printed.
        tokenHash: createHash('sha256').update(randomBytes(32)).digest('hex'),
        sentBy: admin.id,
        sentAt: ago(s.reminderDaysAgo),
        createdAt: ago(s.reminderDaysAgo),
      },
    });
    for (const v of s.verifications ?? []) {
      const at = ago(v.daysAgo);
      const vp = await makePlaceholderJpeg(photoDir, hue++, v.samePhoto ? reportPhoto.buf : undefined);
      const vPhoto = await prisma.photo.create({
        data: {
          storageKey: vp.key, purpose: 'verification', mimeType: 'image/jpeg', byteSize: vp.byteSize,
          widthPx: vp.width, heightPx: vp.height, sha256: vp.sha256,
          uploadedForComplaintId: complaint.id, uploadedAt: at, attachedAt: at,
        },
      });
      await prisma.verification.create({
        data: {
          clientSubmissionId: randomUUID(), complaintId: complaint.id, reminderId: reminder.id,
          result: v.result, photoId: vPhoto.id, latitude: lat + 0.00005, longitude: lng + 0.00005,
          gpsAccuracyM: 10, deviceCapturedAt: at, distanceFromReportM: 7, note: v.note ?? null,
          appPlatform: 'android', appVersion: 'seed', createdAt: at,
        },
      });
    }
  }
  console.log('Seed: reference data and 11 sample complaints created.');
}

main()
  .catch((e) => {
    console.error('Seed failed:', e instanceof Error ? e.message : e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
