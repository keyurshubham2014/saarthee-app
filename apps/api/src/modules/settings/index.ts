/**
 * Public settings and the staff election-mode endpoints (TASK-09 §5.3). TASK-10's settings UI calls these.
 */
import { Router, type Request } from 'express';
import { writeAudit } from '../../lib/audit/staff';
import { rateLimit, ipKey } from '../../middleware/rateLimit';
import { requireStaff } from '../../middleware/requireStaff';
import { validate } from '../../middleware/validate';
import { electionModeSchema, getElectionMode, publicElectionMode, setElectionMode, type ElectionMode } from './electionMode';

export { assertNotElectionFrozen, electionStatus, isElectionMode, invalidateElectionModeCache } from './electionMode';

export const settingsRouter = Router();

const publicLimiter = rateLimit({ windowMs: 60_000, max: 120 });
/** Staff limiter: 300 per actor per minute. */
export const staffKey = (req: Request) => (req.staff ? `u:${req.staff.actorId}` : req.user ? `u:${req.user.id}` : ipKey(req));
const staffLimiter = rateLimit({ windowMs: 60_000, max: 300, keyGenerator: staffKey });

/** Target type per staff action routed through this helper (TASK-09 roster + election mode). */
function targetTypeOf(action: string): string {
  if (action === 'election_mode_set') return 'setting';
  if (action === 'ward_constituencies_updated') return 'ward';
  return 'representative';
}

/**
 * Staff audit line (actor = staff identity, never personal data). TASK-14 sweep: written through the audit
 * destination (AUDIT_LOG_FILE) with actor kind, role and target like every other staff action (REQ-S-010).
 */
export function staffAudit(req: Request, action: string, targetId?: string | null, extra?: Record<string, string | number | boolean | null>) {
  const staff = req.staff;
  writeAudit({
    requestId: req.id,
    actorId: staff?.actorId ?? req.user?.id,
    actorKind: staff?.actorKind ?? 'user',
    role: staff?.role ?? req.user?.role,
    action,
    targetType: targetTypeOf(action),
    targetId: targetId ?? (action === 'election_mode_set' ? 'election_mode' : undefined),
    ...(extra ? { extra } : {}),
  });
}

settingsRouter.get('/settings/public', publicLimiter, async (_req, res) => {
  res.setHeader('Cache-Control', 'public, max-age=60');
  res.json({ electionMode: await publicElectionMode() });
});

settingsRouter.get('/staff/settings/election-mode', requireStaff('admin', 'moderator'), staffLimiter, async (_req, res) => {
  res.json(await getElectionMode());
});

settingsRouter.put(
  '/staff/settings/election-mode',
  requireStaff('admin'),
  staffLimiter,
  validate({ body: electionModeSchema }),
  async (req, res) => {
    const value = await setElectionMode(req.body as ElectionMode, req.staff!.actorId);
    staffAudit(req, 'election_mode_set', null, { enabled: value.enabled, scope: value.scope, wards: value.wardIds.length });
    res.json(value);
  },
);
