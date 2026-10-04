/**
 * TASK-11 scheduled work for the shared runner (summary Open Question 7): `reps-expire` daily at 00:30 IST
 * ends verifications whose term has ended. Idempotent; the request-time term check covers the gap between runs.
 */
import { writeAudit } from '../../lib/audit/staff';
import { expireVerifications } from './review.service';

export interface ModuleJob {
  name: string;
  everyMs?: number;
  cron?: string;
  run: () => Promise<unknown>;
}

export async function runRepsExpire(): Promise<{ expired: number }> {
  const { expired } = await expireVerifications();
  for (const e of expired) {
    writeAudit({ actorId: null, actorKind: 'system', role: 'system', action: 'rep_verification_expired', targetType: 'representative', targetId: e.representativeId });
  }
  return { expired: expired.length };
}

export const jobs: ModuleJob[] = [{ name: 'reps-expire', cron: '30 0 * * *', run: runRepsExpire }];
