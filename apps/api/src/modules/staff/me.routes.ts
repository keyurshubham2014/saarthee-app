/** `/staff/me` and `/staff/summary` (TASK-10 §5.3). */
import { Router } from 'express';
import { prisma } from '../../lib/db';
import type { StaffRole } from '../../middleware/requireStaff';
import { allStaff, moderators } from './common';
import { queueCounts } from './queue.service';

export const meRouter = Router();

/** Server-side nav keys per role (§5.4 order); the app's StaffNavItem registry is the UX source. */
export const STAFF_NAV: Record<StaffRole, string[]> = {
  admin: ['dashboard', 'moderation', 'alerts', 'representatives', 'services', 'initiatives', 'tips', 'categories', 'users', 'settings', 'exports', 'claims'],
  moderator: ['dashboard', 'moderation', 'alerts'],
  // TASK-11 representative console.
  representative: ['ward_dashboard', 'ward_issues', 'messages'],
};

meRouter.get('/staff/me', ...allStaff, async (req, res) => {
  const s = req.staff!;
  const displayName =
    s.actorKind === 'user'
      ? ((await prisma.user.findUnique({ where: { id: s.actorId }, select: { displayName: true } }))?.displayName ?? null)
      : ((await prisma.adminUser.findUnique({ where: { id: s.actorId }, select: { displayName: true } }))?.displayName ?? null);
  res.json({ actorId: s.actorId, actorKind: s.actorKind, role: s.role, displayName, wardIds: s.wardIds, nav: STAFF_NAV[s.role] });
});

meRouter.get('/staff/summary', ...moderators, async (_req, res) => {
  const [queues, alertsAwaitingApproval, openFlags] = await Promise.all([
    queueCounts(),
    prisma.alert.count({ where: { status: 'pending_approval' } }),
    prisma.moderationFlag.count({ where: { status: 'open' } }),
  ]);
  res.json({ queues, alertsAwaitingApproval, openFlags });
});
