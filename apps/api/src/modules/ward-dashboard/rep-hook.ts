/**
 * TASK-11 representative guard on TASK-06's transition() (§5.3 "Representative transition rules"). Runs inside
 * the transition transaction before the state-machine table:
 *   1. ward scope (verified, active, in term — `rep_scope_wards_v`) → 403 WARD_OUT_OF_SCOPE;
 *   2. representatives only acknowledge (from reported/sent) and mark fixed (from any open status);
 *      in_progress, verified, rejected, merged, reopened → 403 FORBIDDEN_ROLE;
 *   3. a note while election mode is on for the ward → 409 ELECTION_MODE_FROZEN (note-less actions pass).
 */
import { AppError } from '../../lib/errors';
import { registerPreTransitionHook, type PreTransitionHook } from '../lifecycle/lifecycle.service';
import { REP_ALLOWED_FROM, repScopeWardIds } from '../rep-claims/scope';
import { isElectionMode } from '../settings/electionMode';

export const representativeTransitionHook: PreTransitionHook = async (tx, issue, to, actor, opts) => {
  if (actor.kind !== 'representative') return;
  const wards = actor.userId ? await repScopeWardIds(actor.userId, tx) : [];
  if (!issue.wardId || !wards.includes(issue.wardId)) throw new AppError('WARD_OUT_OF_SCOPE');
  const from = REP_ALLOWED_FROM[to];
  if (!from) throw new AppError('FORBIDDEN_ROLE');
  if (!from.includes(issue.status)) throw new AppError('INVALID_TRANSITION');
  if (opts.note?.trim() && (await isElectionMode(issue.wardId))) throw new AppError('ELECTION_MODE_FROZEN');
};

registerPreTransitionHook(representativeTransitionHook);
