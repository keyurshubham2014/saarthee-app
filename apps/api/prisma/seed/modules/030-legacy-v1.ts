import { formatLegacyResult, migrateLegacyComplaints } from '../../../src/lib/legacy/migrate';
import { seedLegacyFixtures } from '../legacy-fixtures';
import { defineSeedModule } from '../types';

/**
 * v1 pilot history: invite codes, CCRS categories and complaints C1–C11 (written through
 * withLegacyWrite), then legacy:migrate copies them into v2 issues (hidden, no reporter).
 */
export default defineSeedModule({
  name: 'legacy-v1',
  requires: ['complaints', 'issues', 'categories'],
  async run({ prisma, photoDir, adminEmail, log }) {
    const real = await prisma.complaint.count({ where: { appVersion: { not: 'seed' } } });
    if (real > 0) throw new Error('non-seed complaints exist (real pilot data?). Nothing changed.');
    const admin = await prisma.adminUser.findUniqueOrThrow({ where: { email: adminEmail }, select: { id: true } });
    const created = await seedLegacyFixtures(prisma, photoDir, admin.id);
    log(`Seed legacy-v1: ${created ? '11 v1 complaints created' : 'v1 complaints already present'}`);
    log(`Seed legacy-v1: legacy:migrate ${formatLegacyResult(await migrateLegacyComplaints(prisma))}`);
  },
});
