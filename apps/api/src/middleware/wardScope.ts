import type { StaffIdentity } from './requireStaff';
import { AppError } from '../lib/errors';

/**
 * TASK-10 ward scope (REQ-S-002, shared with TASK-11): admins and moderators see every ward; a representative
 * only the wards in `req.staff.wardIds`. Out of scope (or an issue with no ward) → 403 WARD_OUT_OF_SCOPE.
 */
export function assertWardScope(staff: StaffIdentity | undefined, wardId: string | null | undefined): void {
  if (!staff) throw new AppError('AUTH_REQUIRED');
  if (staff.role === 'admin' || staff.role === 'moderator') return;
  if (!wardId || !staff.wardIds.includes(wardId)) throw new AppError('WARD_OUT_OF_SCOPE');
}
