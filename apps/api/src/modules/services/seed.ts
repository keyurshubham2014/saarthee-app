import type { Prisma, PrismaClient } from '@prisma/client';
import { SERVICES, SERVICES_SOURCE, type ServiceSeed } from '../../../prisma/seed-data/services';

export interface SeedServicesResult {
  inserted: number;
  updated: number;
  unchanged: number;
}

/** Asia/Kolkata midnight of the date the seed URLs were found on the official site. */
export const SOURCE_VERIFIED_AT = new Date(`${SERVICES_SOURCE.checkedOn}T00:00:00+05:30`);

function rowData(s: ServiceSeed): Prisma.ServiceCreateInput {
  return { ...s, verifiedAt: s.isActive ? SOURCE_VERIFIED_AT : null };
}

/**
 * `npm run services:seed` (TASK-12 §6 step 2): inserts missing slugs only, so staff edits are never
 * overwritten; with `force` existing rows are reset from the seed (link-check columns are kept).
 */
export async function seedServices(
  prisma: PrismaClient,
  opts: { force?: boolean; rows?: readonly ServiceSeed[] } = {},
): Promise<SeedServicesResult> {
  const result: SeedServicesResult = { inserted: 0, updated: 0, unchanged: 0 };
  for (const s of opts.rows ?? SERVICES) {
    const existing = await prisma.service.findUnique({ where: { slug: s.slug }, select: { id: true } });
    if (!existing) {
      await prisma.service.create({ data: rowData(s) });
      result.inserted += 1;
    } else if (opts.force) {
      await prisma.service.update({ where: { id: existing.id }, data: rowData(s) });
      result.updated += 1;
    } else {
      result.unchanged += 1;
    }
  }
  return result;
}
