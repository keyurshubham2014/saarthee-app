/**
 * Staff authorisation matrix (TASK-10 §5.3, REQ-S-002) — the written source of truth for every `/staff/*`
 * route. The matrix test (test/staff/matrix.test.ts) walks the Express stack and fails when a registered
 * route is missing here or answers differently from this table. Citizens get 403, visitors 401.
 * When a task adds a `/staff/*` route it appends a row here.
 */
import type { StaffRole } from './requireStaff';

const A: StaffRole[] = ['admin'];
const AM: StaffRole[] = ['admin', 'moderator'];
const AMR: StaffRole[] = ['admin', 'moderator', 'representative'];

export const STAFF_MATRIX: Record<string, StaffRole[]> = {
  // TASK-10 — console, moderation, issue tools.
  'GET /staff/me': AMR,
  'GET /staff/summary': AM,
  'GET /staff/moderation': AM,
  'GET /staff/issues/:id': AM,
  'GET /staff/issues/:id/merge-candidates': AM,
  'POST /staff/issues/:id/reject': AM,
  'POST /staff/issues/:id/merge': AM,
  'POST /staff/issues/:id/recategorise': AM,
  'POST /staff/issues/:id/hide': AM,
  'POST /staff/issues/:id/unhide': AM,
  'POST /staff/issues/:id/reviewed': AM,
  'POST /staff/issues/:id/status': AM,
  'POST /staff/comments/:id/hide': AM,
  'POST /staff/flags/:id/resolve': AM,
  // TASK-10 — users & roles (suspend/unsuspend: moderators for citizens only, enforced in the handler).
  'GET /staff/users': A,
  'POST /staff/users/:id/role': A,
  'POST /staff/users/:id/suspend': AM,
  'POST /staff/users/:id/unsuspend': AM,
  // TASK-10 — categories, settings, exports.
  'GET /staff/categories': AM,
  'POST /staff/categories': A,
  'PATCH /staff/categories/:id': A,
  'GET /staff/settings': AM,
  'PUT /staff/settings/:key': A,
  'GET /staff/export': A,
  // TASK-08 — alerts (moderators and admins; the second-approver rule is enforced in the handler).
  'GET /staff/alerts': AM,
  'GET /staff/alerts/:id': AM,
  'POST /staff/alerts': AM,
  'PATCH /staff/alerts/:id': AM,
  'POST /staff/alerts/:id/submit': AM,
  'POST /staff/alerts/:id/approve': AM,
  'POST /staff/alerts/:id/publish': AM,
  'POST /staff/alerts/:id/retract': AM,
  'POST /staff/alerts/:id/supersede': AM,
  // TASK-09 — representatives roster, constituencies, election mode (moderators read).
  'GET /staff/representatives': AM,
  'GET /staff/representatives/:id': AM,
  'POST /staff/representatives': A,
  'PATCH /staff/representatives/:id': A,
  'DELETE /staff/representatives/:id': A,
  'GET /staff/constituencies': AM,
  'PUT /staff/wards/:id/constituencies': A,
  'GET /staff/settings/election-mode': AM,
  'PUT /staff/settings/election-mode': A,
  // TASK-12 — services (moderators read + link check), initiatives and tips (admins).
  'GET /staff/services': AM,
  'POST /staff/services': A,
  'PATCH /staff/services/:id': A,
  'DELETE /staff/services/:id': A,
  'POST /staff/services/:id/link-check': AM,
  'GET /staff/initiatives': A,
  'GET /staff/initiatives/:id': A,
  'POST /staff/initiatives': A,
  'PATCH /staff/initiatives/:id': A,
  'GET /staff/initiatives/:id/rsvps': A,
  'POST /staff/initiatives/:id/attendance': A,
  'GET /staff/tips': A,
  'POST /staff/tips': A,
  'PATCH /staff/tips/:id': A,
  'DELETE /staff/tips/:id': A,
};
