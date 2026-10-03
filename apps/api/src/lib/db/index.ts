import { Prisma, PrismaClient } from '@prisma/client';

// Single Prisma client. Only services and lib may import this (ARCHITECTURE.md).
export const prisma = new PrismaClient();

/**
 * Runs `fn` in one transaction in which the v1 tables (complaints, reminders, verifications,
 * invite_codes, ccrs_categories) are writable and issue_events may be corrected
 * (`saarthee.legacy_write = on`, transaction-local). Without it the database triggers raise
 * LEGACY_READ_ONLY (V2 TASK-01 §5.2). Use only for: the legacy migration, the v1 anonymize path,
 * seeds and test factories (and TASK-04 erasure of issue_events.actor_id).
 */
export async function withLegacyWrite<T>(
  fn: (tx: Prisma.TransactionClient) => Promise<T>,
  client: PrismaClient = prisma,
  options?: { timeout?: number },
): Promise<T> {
  return client.$transaction(
    async (tx) => {
      await tx.$queryRaw`SELECT set_config('saarthee.legacy_write', 'on', true)`;
      return fn(tx);
    },
    { timeout: options?.timeout ?? 30_000 },
  );
}

/** True when `err` is the database's LEGACY_READ_ONLY trigger error. */
export function isLegacyReadOnlyError(err: unknown): boolean {
  return err instanceof Error && err.message.includes('LEGACY_READ_ONLY');
}
