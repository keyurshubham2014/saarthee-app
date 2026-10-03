// Orphaned-photo cleanup + retry of failed anonymization file deletions (03 §5.3). Safe to re-run.
// Usage: npm run photos:cleanup   (in apps/api)
import { prisma } from '../src/lib/db';
import { cleanupPhotos } from '../src/modules/photos/cleanup.service';

async function main() {
  const r = await cleanupPhotos();
  console.log(
    `photos:cleanup orphans deleted=${r.orphansDeleted} anonymized files deleted=${r.anonymizedFilesDeleted} failures=${r.failures}`,
  );
  if (r.failures > 0) process.exitCode = 1;
}

main()
  .catch((err: unknown) => {
    console.error('photos:cleanup failed:', err instanceof Error ? err.message : 'unknown error');
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
