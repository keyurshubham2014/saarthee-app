import type { PrismaClient } from '@prisma/client';
import { prisma } from '../../lib/db';

export interface Health {
  /** PostGIS library version, e.g. "3.5.2". */
  postgis: string;
}

/** DB round trip + PostGIS version (V2 TASK-01 §5.3). null = database unreachable or too slow. */
export async function checkHealth(client: PrismaClient = prisma, timeoutMs = 2000): Promise<Health | null> {
  let timer: NodeJS.Timeout | undefined;
  try {
    const rows = await Promise.race([
      client.$queryRaw<{ v: string }[]>`SELECT postgis_lib_version() AS v`,
      new Promise<never>((_, reject) => {
        timer = setTimeout(() => reject(new Error('timeout')), timeoutMs);
      }),
    ]);
    return { postgis: rows[0]?.v ?? 'unknown' };
  } catch {
    return null;
  } finally {
    if (timer) clearTimeout(timer);
  }
}
