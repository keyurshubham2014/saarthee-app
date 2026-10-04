/**
 * TASK-11 representative console API (REQ-F-054/055): ward scope list, ward dashboard, CSV export, ward issue
 * list with allowedActions, staff comments. Scope is enforced server-side on every route (assertWardScope over
 * `req.staff.wardIds`, which requireStaff fills from `rep_scope_wards_v` — verified, active, in term).
 * Importing this module also registers the representative pre-transition hook on TASK-06's transition().
 */
import type { Request } from 'express';
import { Router } from 'express';
import { z } from 'zod';
import { config } from '../../config';
import { auditStaff } from '../../lib/audit';
import { now as clockNow } from '../../lib/clock';
import { prisma } from '../../lib/db';
import { AppError } from '../../lib/errors';
import { rateLimit } from '../../middleware/rateLimit';
import { requireStaff } from '../../middleware/requireStaff';
import { validate } from '../../middleware/validate';
import { assertWardScope } from '../../middleware/wardScope';
import { electionStatus, isElectionMode } from '../settings/electionMode';
import { wardDashboard } from './dashboard.service';
import './rep-hook';
import { wardCsv, wardIssues } from './ward.service';

export const wardDashboardRouter = Router();

const actorKey = (p: string) => (req: Request) => `${p}:${req.staff?.actorId ?? 'none'}`;
const staff = requireStaff('admin', 'moderator', 'representative');
const dashLimiter = rateLimit({ windowMs: 60_000, max: 60, keyGenerator: actorKey('ward-dash') });
const exportLimiter = rateLimit({ windowMs: 60 * 60_000, max: config.REP_EXPORT_MAX_PER_HOUR, keyGenerator: actorKey('ward-export') });
const commentLimiter = rateLimit({ windowMs: 60 * 60_000, max: 30, keyGenerator: actorKey('ward-comment') });
const listLimiter = rateLimit({ windowMs: 60_000, max: 120, keyGenerator: actorKey('ward-list') });

const DAY = 86_400_000;
const wardQuery = z.object({ ward: z.uuid() });
const exportQuery = z
  .object({ ward: z.uuid(), from: z.iso.date(), to: z.iso.date() })
  .superRefine((q, ctx) => {
    const span = (Date.parse(q.to) - Date.parse(q.from)) / DAY;
    if (span < 0) ctx.addIssue({ code: 'custom', path: ['to'], message: 'must be on or after from' });
    if (span > 366) ctx.addIssue({ code: 'custom', path: ['to'], message: 'range must be 366 days or less' });
  });
const STATUSES = ['reported', 'sent', 'acknowledged', 'in_progress', 'marked_fixed', 'verified', 'reopened'] as const;
const issuesQuery = z.object({
  ward: z.uuid(),
  status: z.enum(STATUSES).optional(),
  overdue: z.enum(['true', 'false']).optional().transform((v) => v === 'true'),
  cursor: z.string().max(200).optional(),
  limit: z.coerce.number().int().min(1).max(50).default(25),
});
const idParams = z.object({ id: z.uuid() });
const commentBody = z.strictObject({ note: z.string().trim().min(1).max(500) });

/** Wards the ward switcher offers: a representative's scope; every ward for moderators and admins. */
wardDashboardRouter.get('/staff/ward/scope', staff, listLimiter, async (req, res) => {
  const s = req.staff!;
  const where = s.role === 'representative' ? { id: { in: s.wardIds } } : {};
  const wards = await prisma.ward.findMany({ where, orderBy: { number: 'asc' }, select: { id: true, number: true, nameEn: true, nameGu: true } });
  res.json({ items: wards });
});

wardDashboardRouter.get('/staff/ward-dashboard', staff, dashLimiter, validate({ query: wardQuery }), async (req, res) => {
  const { ward } = res.locals.query as z.infer<typeof wardQuery>;
  assertWardScope(req.staff, ward);
  const [body, election] = await Promise.all([wardDashboard(ward), electionStatus(ward)]);
  res.setHeader('Cache-Control', 'no-store');
  res.json({ ...body, electionMode: { active: election.active, until: election.until } });
});

wardDashboardRouter.get('/staff/ward-dashboard/export', staff, validate({ query: exportQuery }), async (req, res, next) => {
  const q = res.locals.query as z.infer<typeof exportQuery>;
  assertWardScope(req.staff, q.ward);
  exportLimiter(req, res, async (err?: unknown) => {
    if (err) return next(err);
    try {
      const at = clockNow();
      const out = await wardCsv(q.ward, q.from, q.to, at);
      auditStaff(req, 'ward_export', { targetType: 'ward', targetId: q.ward, extra: { rows: out.rows } });
      const day = at.toISOString().slice(0, 10).replace(/-/g, '');
      res.setHeader('Content-Type', 'text/csv; charset=utf-8');
      res.setHeader('Content-Disposition', `attachment; filename="saarthee-ward-${out.wardNumber}-${day}.csv"`);
      res.setHeader('Cache-Control', 'no-store');
      res.send(out.csv);
    } catch (e) {
      next(e);
    }
  });
});

wardDashboardRouter.get('/staff/ward/issues', staff, listLimiter, validate({ query: issuesQuery }), async (req, res) => {
  const q = res.locals.query as z.infer<typeof issuesQuery>;
  assertWardScope(req.staff, q.ward);
  const [page, election] = await Promise.all([wardIssues(q, req.staff!.role, clockNow()), electionStatus(q.ward)]);
  res.json({ ...page, electionMode: { active: election.active, until: election.until } });
});

wardDashboardRouter.post('/staff/issues/:id/comments', staff, commentLimiter, validate({ params: idParams, body: commentBody }), async (req, res) => {
  const { id } = res.locals.params as z.infer<typeof idParams>;
  const { note } = req.body as z.infer<typeof commentBody>;
  const s = req.staff!;
  const issue = await prisma.issue.findUnique({ where: { id }, select: { wardId: true, status: true } });
  if (!issue) throw new AppError('NOT_FOUND');
  assertWardScope(s, issue.wardId);
  if (s.role === 'representative' && issue.wardId && (await isElectionMode(issue.wardId))) throw new AppError('ELECTION_MODE_FROZEN');
  if (issue.status === 'rejected' || issue.status === 'merged') throw new AppError('ISSUE_NOT_OPEN');
  const event = await prisma.issueEvent.create({
    data: { issueId: id, actorId: s.actorKind === 'user' ? s.actorId : null, actorRole: s.role, type: 'comment', note },
    select: { id: true },
  });
  auditStaff(req, 'rep_issue_comment', { targetType: 'issue', targetId: id, extra: { eventId: event.id } });
  res.status(201).json({ eventId: event.id });
});
