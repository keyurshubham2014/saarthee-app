/**
 * Derived lifecycle fields returned by every issue serializer (V2 TASK-06 §5.2, REQ-F-023/024):
 * `isOverdue`, `verifyWindowClosesAt`, `displayStatus` (`fixed_unverified` after the reopen window).
 * Computed at read time; nothing is stored and no job is needed.
 */
import type { IssueStatus } from '@prisma/client';
import { config } from '../../config';
import { now as clockNow } from '../../lib/clock';
import { OPEN_STATUSES, VERIFIABLE_STATUSES } from '../lifecycle/transitions';

export type DisplayStatus = IssueStatus | 'fixed_unverified';

export interface DerivedFields {
  isOverdue: boolean;
  verifyWindowClosesAt: Date | null;
  displayStatus: DisplayStatus;
}

export interface DerivableIssue {
  status: IssueStatus;
  slaDueAt: Date;
  markedFixedAt: Date | null;
}

export function verifyWindowClosesAt(issue: DerivableIssue): Date | null {
  if (!VERIFIABLE_STATUSES.includes(issue.status) || !issue.markedFixedAt) return null;
  return new Date(issue.markedFixedAt.getTime() + config.REOPEN_WINDOW_DAYS * 86_400_000);
}

export function deriveIssue(issue: DerivableIssue, now: Date = clockNow()): DerivedFields {
  const closes = verifyWindowClosesAt(issue);
  const windowClosed = closes !== null && now.getTime() > closes.getTime();
  return {
    isOverdue: OPEN_STATUSES.includes(issue.status) && now.getTime() > issue.slaDueAt.getTime(),
    verifyWindowClosesAt: closes,
    displayStatus: issue.status === 'marked_fixed' && windowClosed ? 'fixed_unverified' : issue.status,
  };
}

/** Public issue shape for lifecycle responses (no reporter id, phone or name). */
export function serializeIssue(issue: DerivableIssue & {
  id: string; wardId: string | null; meTooCount: number; reopenedCount: number; statusChangedAt: Date; statusVersion: number;
  verifiedAt: Date | null; ccrsNumber: string | null; ccrsClosedAt: Date | null;
}) {
  return {
    id: issue.id, status: issue.status, statusChangedAt: issue.statusChangedAt, statusVersion: issue.statusVersion,
    wardId: issue.wardId, slaDueAt: issue.slaDueAt, markedFixedAt: issue.markedFixedAt, verifiedAt: issue.verifiedAt,
    reopenedCount: issue.reopenedCount, meTooCount: issue.meTooCount, ccrsLinked: issue.ccrsNumber !== null,
    ccrsClosedAt: issue.ccrsClosedAt, ...deriveIssue(issue),
  };
}
