/**
 * TASK-11 representative scope (REQ-S-002, REQ-F-055): which wards a signed-in representative may act on.
 * Reads `rep_scope_wards_v` — verified, active, in-term rows only, so a term that ended yesterday gives an
 * empty scope at request time even before the `reps:expire` job runs. MLA/MP rows cover every ward mapped to
 * their constituency through `ward_constituency`.
 */
import type { IssueStatus, Prisma } from '@prisma/client';
import { prisma } from '../../lib/db';

type Db = Prisma.TransactionClient | typeof prisma;

export interface RepScope {
  representativeIds: string[];
  wardIds: string[];
}

export async function getRepScope(userId: string, db: Db = prisma): Promise<RepScope> {
  const rows = await db.$queryRaw<{ representative_id: string; ward_id: string }[]>`
    SELECT representative_id::text, ward_id::text FROM rep_scope_wards_v WHERE user_id = ${userId}::uuid`;
  return {
    representativeIds: [...new Set(rows.map((r) => r.representative_id))],
    wardIds: [...new Set(rows.map((r) => r.ward_id))],
  };
}

export async function repScopeWardIds(userId: string, db: Db = prisma): Promise<string[]> {
  return (await getRepScope(userId, db)).wardIds;
}

/** Representative status changes (§5.3 rule table): acknowledge and mark fixed only; never in_progress,
 * verified, rejected, merged or reopened. */
export const REP_ALLOWED_FROM: Partial<Record<IssueStatus, readonly IssueStatus[]>> = {
  acknowledged: ['reported', 'sent'],
  marked_fixed: ['reported', 'sent', 'acknowledged', 'in_progress', 'reopened'],
};

export type RepAction = 'acknowledge' | 'mark_fixed' | 'comment';

/** Actions a representative may offer for an issue in their scope (drives `allowedActions` in the UI). */
export function repAllowedActions(status: IssueStatus): RepAction[] {
  const out: RepAction[] = [];
  if (REP_ALLOWED_FROM.acknowledged!.includes(status)) out.push('acknowledge');
  if (REP_ALLOWED_FROM.marked_fixed!.includes(status)) out.push('mark_fixed');
  if (status !== 'rejected' && status !== 'merged') out.push('comment');
  return out;
}
