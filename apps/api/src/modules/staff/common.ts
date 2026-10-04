/** TASK-10 staff console shared guards and params. Every `/staff/*` route here uses one of these chains. */
import type { Request } from 'express';
import { z } from 'zod';
import { rateLimit } from '../../middleware/rateLimit';
import { requireStaff } from '../../middleware/requireStaff';
import type { StatusActor } from './status.service';

const actorKey = (req: Request) => `staff10:${req.staff?.actorId ?? 'none'}`;
/** Per-actor limiter: 300 requests per minute. */
const limiter = rateLimit({ windowMs: 60_000, max: 300, keyGenerator: actorKey });

export const allStaff = [requireStaff('admin', 'moderator', 'representative'), limiter];
export const moderators = [requireStaff('admin', 'moderator'), limiter];
export const admins = [requireStaff('admin'), limiter];

export const idParams = z.object({ id: z.uuid() });
export type IdParams = z.infer<typeof idParams>;

export const idOf = (res: { locals: Record<string, unknown> }) => (res.locals.params as IdParams).id;

/** `actor_role` for issue_events from the staff identity (v1 admin JWT → admin, no user id). */
export function eventActor(req: Request): StatusActor {
  const s = req.staff!;
  return { actorId: s.actorKind === 'user' ? s.actorId : null, handlerId: s.actorId, actorRole: s.role };
}

/** Masks a phone for staff lists: '+91 ••••••3210'. */
export function maskPhone(phone: string | null): string | null {
  if (!phone) return null;
  const last4 = phone.slice(-4);
  return `${phone.startsWith('+91') ? '+91 ' : ''}••••••${last4}`;
}
