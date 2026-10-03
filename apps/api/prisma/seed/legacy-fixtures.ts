/* v1 pilot fixtures C1–C11 (apps/api/prisma/SEED-EXPECTATIONS.md, v1 section). Written through
 * withLegacyWrite because v1 tables are read-only in v2. Shared by the legacy-v1 seed module and the
 * test factories (T-01-05). */
import { createHash, randomBytes, randomUUID } from 'node:crypto';
import type { PrismaClient, SourceTag, VerificationResult } from '@prisma/client';
import { withLegacyWrite } from '../../src/lib/db';
import { makePlaceholderJpeg } from './seed-photo';
import { daysAgo } from './types';

export const LEGACY_CCRS_CATEGORIES = [
  'Pothole or damaged road',
  'Garbage and cleanliness',
  'Streetlight',
  'Drainage',
  'Water supply',
  'Other',
] as const;

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

export const LEGACY_SPECS: readonly Spec[] = [
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

/** Invite codes + CCRS categories (create-if-missing) and, when no complaint exists yet, C1–C11. */
export async function seedLegacyFixtures(prisma: PrismaClient, photoDir: string, adminId: string): Promise<boolean> {
  return withLegacyWrite(
    async (tx) => {
      const codes: [string, SourceTag, string][] = [
        ['RWATEST01', 'rwa', 'Test RWA — Navrangpura'],
        ['ACTTEST01', 'activist', 'Test activist group'],
        ['SOCTEST01', 'social', 'Test social media post'],
        ['NETTEST01', 'network', 'Test personal network'],
      ];
      const inviteIds: Record<string, string> = {};
      for (const [code, sourceTag, groupLabel] of codes) {
        const row =
          (await tx.inviteCode.findUnique({ where: { code }, select: { id: true } })) ??
          (await tx.inviteCode.create({ data: { code, sourceTag, groupLabel, createdBy: adminId }, select: { id: true } }));
        inviteIds[sourceTag] = row.id;
      }
      const catIds: string[] = [];
      for (const [i, name] of LEGACY_CCRS_CATEGORIES.entries()) {
        const row =
          (await tx.ccrsCategory.findUnique({ where: { name }, select: { id: true } })) ??
          (await tx.ccrsCategory.create({ data: { name, sortOrder: (i + 1) * 10 }, select: { id: true } }));
        catIds.push(row.id);
      }

      if ((await tx.complaint.count()) > 0) return false;

      let hue = 1;
      const seen = new Set<string>();
      for (const s of LEGACY_SPECS) {
        const lat = 23.0225 + s.n * 0.0011;
        const lng = 72.5714 + s.n * 0.0013;
        const created = daysAgo(s.createdDaysAgo);
        const reportPhoto = await makePlaceholderJpeg(photoDir, hue++);
        const photo = await tx.photo.create({
          data: {
            storageKey: reportPhoto.key, purpose: 'report', mimeType: 'image/jpeg', byteSize: reportPhoto.byteSize,
            widthPx: reportPhoto.width, heightPx: reportPhoto.height, sha256: reportPhoto.sha256,
            uploadedAt: created, attachedAt: created,
          },
        });
        const normalized = s.ccrs.toUpperCase().replace(/[\s-]/g, '');
        const complaint = await tx.complaint.create({
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
            excludedBy: s.excluded ? adminId : null,
            excludedAt: s.excluded ? daysAgo(1) : null,
            createdAt: created,
          },
        });
        seen.add(normalized);
        if (s.reminderDaysAgo === undefined) continue;
        const reminder = await tx.reminder.create({
          data: {
            complaintId: complaint.id,
            // Hash of a random token that is discarded and never printed.
            tokenHash: createHash('sha256').update(randomBytes(32)).digest('hex'),
            sentBy: adminId,
            sentAt: daysAgo(s.reminderDaysAgo),
            createdAt: daysAgo(s.reminderDaysAgo),
          },
        });
        for (const v of s.verifications ?? []) {
          const at = daysAgo(v.daysAgo);
          const vp = await makePlaceholderJpeg(photoDir, hue++, v.samePhoto ? reportPhoto.buf : undefined);
          const vPhoto = await tx.photo.create({
            data: {
              storageKey: vp.key, purpose: 'verification', mimeType: 'image/jpeg', byteSize: vp.byteSize,
              widthPx: vp.width, heightPx: vp.height, sha256: vp.sha256,
              uploadedForComplaintId: complaint.id, uploadedAt: at, attachedAt: at,
            },
          });
          await tx.verification.create({
            data: {
              clientSubmissionId: randomUUID(), complaintId: complaint.id, reminderId: reminder.id,
              result: v.result, photoId: vPhoto.id, latitude: lat + 0.00005, longitude: lng + 0.00005,
              gpsAccuracyM: 10, deviceCapturedAt: at, distanceFromReportM: 7, note: v.note ?? null,
              appPlatform: 'android', appVersion: 'seed', createdAt: at,
            },
          });
        }
      }
      return true;
    },
    prisma,
    { timeout: 120_000 },
  );
}
