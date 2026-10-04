/** Users & roles and suspension (TASK-10 §5.3/§5.5). Phones are only ever returned masked. */
import { Router, type Request } from 'express';
import type { Prisma } from '@prisma/client';
import { z } from 'zod';
import { auditStaff } from '../../lib/audit';
import { prisma } from '../../lib/db';
import { AppError } from '../../lib/errors';
import { validate } from '../../middleware/validate';
import { admins, idOf, idParams, maskPhone, moderators } from './common';

export const usersRouter = Router();

const listQuery = z.object({
  q: z.string().trim().max(60).optional(),
  role: z.enum(['citizen', 'moderator', 'admin', 'representative']).optional(),
  cursor: z.string().regex(/^\d{1,6}$/).optional(),
});
const roleBody = z.strictObject({ role: z.enum(['moderator', 'citizen']) });
const reasonBody = z.strictObject({ reason: z.string().trim().min(1).max(200) });
const PAGE = 50;

const isSelf = (req: Request, userId: string) => req.staff!.actorKind === 'user' && req.staff!.actorId === userId;

usersRouter.get('/staff/users', ...admins, validate({ query: listQuery }), async (_req, res) => {
  const q = res.locals.query as z.infer<typeof listQuery>;
  const where: Prisma.UserWhereInput = { status: { not: 'deleted' }, ...(q.role ? { role: q.role } : {}) };
  if (q.q) {
    if (/^\d{4}$/.test(q.q)) where.phoneE164 = { endsWith: q.q };
    else where.displayName = { contains: q.q, mode: 'insensitive' };
  }
  const offset = Number(q.cursor ?? 0);
  const rows = await prisma.user.findMany({
    where, orderBy: [{ createdAt: 'desc' }, { id: 'asc' }], skip: offset, take: PAGE + 1,
    select: { id: true, displayName: true, phoneE164: true, role: true, status: true, createdAt: true },
  });
  res.json({
    items: rows.slice(0, PAGE).map((u) => ({
      id: u.id, displayName: u.displayName, phoneMasked: maskPhone(u.phoneE164), role: u.role, status: u.status, createdAt: u.createdAt,
    })),
    nextCursor: rows.length > PAGE ? String(offset + PAGE) : null,
  });
});

usersRouter.post('/staff/users/:id/role', ...admins, validate({ params: idParams, body: roleBody }), async (req, res) => {
  const id = idOf(res);
  const { role } = req.body as z.infer<typeof roleBody>;
  if (isSelf(req, id)) throw new AppError('SELF_ROLE_CHANGE');
  const user = await prisma.user.findUnique({ where: { id }, select: { role: true, status: true } });
  if (!user || user.status === 'deleted') throw new AppError('NOT_FOUND');
  if (user.role === 'admin' || user.role === 'representative') throw new AppError('ROLE_CHANGE_INVALID');
  const updated = await prisma.user.update({ where: { id }, data: { role, tokenVersion: { increment: 1 } } });
  auditStaff(req, 'role_changed', { targetType: 'user', targetId: id, extra: { from: user.role, to: role } });
  res.json({ id, role: updated.role, status: updated.status });
});

async function changeStatus(req: Request, id: string, to: 'suspended' | 'active') {
  if (isSelf(req, id)) throw new AppError('SELF_SUSPEND');
  const user = await prisma.user.findUnique({ where: { id }, select: { role: true, status: true } });
  if (!user || user.status === 'deleted') throw new AppError('NOT_FOUND');
  // Moderators act on citizens only; only admins suspend or reinstate staff.
  if (req.staff!.role !== 'admin' && user.role !== 'citizen') throw new AppError('FORBIDDEN');
  if (user.status === to) throw new AppError('USER_STATE_INVALID');
  return prisma.user.update({
    where: { id },
    data: { status: to, ...(to === 'suspended' ? { tokenVersion: { increment: 1 } } : {}) },
    select: { id: true, role: true, status: true },
  });
}

usersRouter.post('/staff/users/:id/suspend', ...moderators, validate({ params: idParams, body: reasonBody }), async (req, res) => {
  const id = idOf(res);
  const user = await changeStatus(req, id, 'suspended');
  auditStaff(req, 'user_suspended', { targetType: 'user', targetId: id, extra: { targetRole: user.role } });
  res.json(user);
});

usersRouter.post('/staff/users/:id/unsuspend', ...moderators, validate({ params: idParams, body: reasonBody }), async (req, res) => {
  const id = idOf(res);
  const user = await changeStatus(req, id, 'active');
  auditStaff(req, 'user_unsuspended', { targetType: 'user', targetId: id, extra: { targetRole: user.role } });
  res.json(user);
});
