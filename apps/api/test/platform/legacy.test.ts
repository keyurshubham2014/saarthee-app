// T-01-05 (AC-7): v1 complaints C1–C11 copied into issues with mapped status, idempotently.
import { beforeEach, describe, expect, it } from 'vitest';
import categoriesDev from '../../prisma/seed/modules/020-categories-dev';
import { seedLegacyFixtures } from '../../prisma/seed/legacy-fixtures';
import { prisma } from '../../src/lib/db';
import { LegacyMigrationError, migrateLegacyComplaints } from '../../src/lib/legacy/migrate';
import { createAdmin } from '../helpers/auth';
import { resetDb } from '../helpers/db';
import { makeCcrsCategory, makeComplaint } from '../helpers/factories';

const ctx = () => ({
  prisma,
  photoDir: process.env.PHOTO_STORAGE_DIR!,
  adminEmail: 'x@test.local',
  adminPassword: 'x',
  log: () => undefined,
});

beforeEach(resetDb);

describe('legacy:migrate', () => {
  it('imports C1–C11 once, with mapped status, hidden, no reporter and ordered history', async () => {
    const { admin } = await createAdmin();
    await categoriesDev.run(ctx());
    expect(await seedLegacyFixtures(prisma, ctx().photoDir, admin.id)).toBe(true);

    // Small batches exercise the batching loop (3 transactions).
    expect(await migrateLegacyComplaints(prisma, { batchSize: 4 })).toEqual({ complaints: 11, imported: 11, skipped: 0 });
    expect(await migrateLegacyComplaints(prisma)).toEqual({ complaints: 11, imported: 0, skipped: 11 });

    const issues = await prisma.issue.findMany({
      where: { legacyComplaintId: { not: null } },
      include: { photos: true, events: { orderBy: [{ createdAt: 'asc' }] }, legacyComplaint: { include: { verifications: true } } },
    });
    expect(issues).toHaveLength(11);
    const counts = issues.reduce<Record<string, number>>((acc, i) => ({ ...acc, [i.status]: (acc[i.status] ?? 0) + 1 }), {});
    expect(counts).toEqual({ reported: 3, sent: 2, verified: 2, reopened: 4 });

    for (const i of issues) {
      const c = i.legacyComplaint!;
      expect(i.visibility).toBe('hidden');
      expect(i.reporterId).toBeNull();
      expect(i.ccrsNumber).toBe(c.ccrsNumberRaw);
      expect(i.ccrsFiledAt?.getTime()).toBe(c.createdAt.getTime());
      expect(i.lat.toNumber()).toBe(c.latitude.toNumber());
      expect(i.clientSubmissionId).toBe(c.clientSubmissionId);
      expect(i.slaDueAt.getTime()).toBe(c.createdAt.getTime() + 7 * 86_400_000);
      const report = i.photos.filter((p) => p.kind === 'report');
      expect(report).toEqual([expect.objectContaining({ photoId: c.photoId, position: 0 })]);
      expect(i.photos.filter((p) => p.kind === 'verification').map((p) => p.photoId).sort()).toEqual(
        c.verifications.map((v) => v.photoId).sort(),
      );
      // History: starts with null → reported, each from_status is the previous to_status, ends at the current status.
      expect(i.events[0]).toMatchObject({ fromStatus: null, toStatus: 'reported', actorRole: 'system', type: 'status_change' });
      i.events.slice(1).forEach((e, k) => expect(e.fromStatus).toBe(i.events[k]!.toStatus));
      expect(i.events.at(-1)!.toStatus).toBe(i.status);
      expect(i.statusChangedAt.getTime()).toBe(i.events.at(-1)!.createdAt.getTime());
    }

    // C6: reminded, verified fixed, then not fixed.
    const c6 = issues.find((i) => i.ccrsNumber === 'AMC-2026-0006')!;
    expect(c6.events.map((e) => e.toStatus)).toEqual(['reported', 'sent', 'verified', 'reopened']);
    expect(c6.title).toBe('Roads & potholes'); // C6 → 'Pothole or damaged road' → roads

    // No phone number reaches a v2 table.
    expect(await prisma.user.count()).toBe(0);
    const [leak] = await prisma.$queryRaw<{ n: bigint }[]>`
      SELECT (SELECT count(*) FROM issues WHERE row_to_json(issues)::text LIKE '%+91900%')
           + (SELECT count(*) FROM issue_events WHERE row_to_json(issue_events)::text LIKE '%+91900%') AS n`;
    expect(Number(leak!.n)).toBe(0);
  });

  it('refuses when categories is empty', async () => {
    await expect(migrateLegacyComplaints(prisma)).rejects.toThrow('Seed categories first');
  });

  it('fails listing unknown v1 category names and imports nothing', async () => {
    await categoriesDev.run(ctx());
    const cat = await makeCcrsCategory('Mystery category');
    await makeComplaint({ categoryId: cat.id });
    const err = await migrateLegacyComplaints(prisma).catch((e: unknown) => e);
    expect(err).toBeInstanceOf(LegacyMigrationError);
    expect((err as Error).message).toContain('Mystery category');
    expect(await prisma.issue.count()).toBe(0);
  });
});
