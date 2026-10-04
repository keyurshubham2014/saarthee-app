/**
 * Public settings and the staff election-mode endpoints (TASK-09 §5.3). TASK-10's settings UI calls these.
 */
import { Router, type Request } from 'express';
import { logger } from '../../lib/logger';
import { rateLimit, ipKey } from '../../middleware/rateLimit';
import { requireRole, requireUser } from '../../middleware/requireUser';
import { validate } from '../../middleware/validate';
import { electionModeSchema, getElectionMode, publicElectionMode, setElectionMode, type ElectionMode } from './electionMode';

export { assertNotElectionFrozen, electionStatus, isElectionMode, invalidateElectionModeCache } from './electionMode';

export const settingsRouter = Router();

const publicLimiter = rateLimit({ windowMs: 60_000, max: 120 });
/** Staff limiter: 300 per actor per minute. */
export const staffKey = (req: Request) => (req.user ? `u:${req.user.id}` : ipKey(req));
const staffLimiter = rateLimit({ windowMs: 60_000, max: 300, keyGenerator: staffKey });

/** Staff audit line (actor = staff user id, never personal data). */
export function staffAudit(req: Request, action: string, targetId?: string | null, extra?: Record<string, string | number | boolean | null>) {
  logger.info({ requestId: req.id, actorId: req.user?.id, actorRole: req.user?.role, action, targetId: targetId ?? undefined, ...(extra ?? {}) }, 'staff_action');
}

settingsRouter.get('/settings/public', publicLimiter, async (_req, res) => {
  res.setHeader('Cache-Control', 'public, max-age=60');
  res.json({ electionMode: await publicElectionMode() });
});

settingsRouter.get('/staff/settings/election-mode', requireUser, requireRole('admin', 'moderator'), staffLimiter, async (_req, res) => {
  res.json(await getElectionMode());
});

settingsRouter.put(
  '/staff/settings/election-mode',
  requireUser,
  requireRole('admin'),
  staffLimiter,
  validate({ body: electionModeSchema }),
  async (req, res) => {
    const value = await setElectionMode(req.body as ElectionMode, req.user!.id);
    staffAudit(req, 'election_mode_set', null, { enabled: value.enabled, scope: value.scope, wards: value.wardIds.length });
    res.json(value);
  },
);
