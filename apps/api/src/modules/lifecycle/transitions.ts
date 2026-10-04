/**
 * The issue state machine (V2 TASK-06 §5.3, Spec §5, REQ-F-020). Pure data + checks; `transition()` in
 * lifecycle.service.ts is the only code that writes `issues.status`.
 */
import type { IssueStatus } from '@prisma/client';

/** Who is acting, relative to this issue: `reporter` when the user reported it, else their role. */
export type ActorKind = 'reporter' | 'citizen' | 'representative' | 'moderator' | 'admin' | 'system';

export const OPEN_STATUSES: readonly IssueStatus[] = ['reported', 'sent', 'acknowledged', 'in_progress', 'reopened'];
export const TERMINAL_STATUSES: readonly IssueStatus[] = ['rejected', 'merged'];
export const VERIFIABLE_STATUSES: readonly IssueStatus[] = ['marked_fixed', 'verified'];

export interface TransitionRule {
  from: readonly IssueStatus[];
  to: IssueStatus;
  actors: readonly ActorKind[];
  /** Representatives may act only on issues in their own (verified) wards. */
  wardScoped?: boolean;
  /** Reporter allowed only when a CCRS number is linked ("AMC acknowledged"). */
  reporterNeedsCcrs?: boolean;
  noteRequired?: boolean;
}

const STAFF: readonly ActorKind[] = ['representative', 'moderator', 'admin'];

export const TRANSITIONS: readonly TransitionRule[] = [
  { from: ['reported'], to: 'sent', actors: ['reporter', 'system'] },
  { from: ['reported', 'sent', 'reopened'], to: 'acknowledged', actors: [...STAFF, 'reporter'], wardScoped: true, reporterNeedsCcrs: true },
  { from: ['reported', 'sent', 'acknowledged', 'reopened'], to: 'in_progress', actors: STAFF, wardScoped: true },
  { from: OPEN_STATUSES, to: 'marked_fixed', actors: ['reporter', ...STAFF], wardScoped: true },
  { from: ['marked_fixed'], to: 'verified', actors: ['system'] },
  { from: ['marked_fixed', 'verified'], to: 'reopened', actors: ['system'] },
  { from: [...OPEN_STATUSES, 'marked_fixed'], to: 'rejected', actors: ['moderator', 'admin'], noteRequired: true },
  { from: [...OPEN_STATUSES, 'marked_fixed'], to: 'merged', actors: ['moderator', 'admin'] },
];

export type TransitionCheck =
  | { ok: true; rule: TransitionRule }
  | { ok: false; code: 'INVALID_TRANSITION' | 'FORBIDDEN_ROLE' };

/**
 * Table check only (ward scope and CCRS are checked by the caller with data): a (from, to) pair that is not
 * in the table is INVALID_TRANSITION; a pair in the table with a disallowed actor is FORBIDDEN_ROLE.
 */
export function checkTransition(from: IssueStatus, to: IssueStatus, actor: ActorKind): TransitionCheck {
  const rule = TRANSITIONS.find((r) => r.to === to && r.from.includes(from));
  if (!rule) return { ok: false, code: 'INVALID_TRANSITION' };
  if (!rule.actors.includes(actor)) return { ok: false, code: 'FORBIDDEN_ROLE' };
  return { ok: true, rule };
}

/** Actor role stored on issue_events (`actor_role` enum has no `reporter`). */
export function eventActorRole(actor: ActorKind): 'citizen' | 'representative' | 'moderator' | 'admin' | 'system' {
  return actor === 'reporter' ? 'citizen' : actor;
}
