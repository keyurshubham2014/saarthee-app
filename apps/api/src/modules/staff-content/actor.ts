import type { Request } from 'express';

/**
 * The users.id to store in created_by / updated_by / attendance_marked_by (FKs to users). A v1 admin login
 * (actorKind admin_user) has no users row, so those columns stay null; the audit line still names the actor.
 */
export function staffUserId(req: Request): string | null {
  return req.staff?.actorKind === 'user' ? req.staff.actorId : null;
}
