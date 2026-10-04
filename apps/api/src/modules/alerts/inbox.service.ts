import type { AppLanguage } from '@prisma/client';
import { z } from 'zod';
import { prisma } from '../../lib/db';
import { decodeCursor, encodeCursor } from '../../lib/pagination';
import { effectiveStatus } from './dto';

export const INBOX_DAYS = 90;
const DAY_MS = 86_400_000;

export const markReadBody = z.union([
  z.strictObject({ ids: z.array(z.uuid()).min(1).max(100) }),
  z.strictObject({ all: z.literal(true) }),
]);

const windowStart = (now: Date) => new Date(now.getTime() - INBOX_DAYS * DAY_MS);

export async function unreadCount(userId: string, now: Date): Promise<number> {
  return prisma.notification.count({ where: { userId, readAt: null, createdAt: { gte: windowStart(now) } } });
}

/**
 * GET /me/notifications (§5.3): the caller's rows of the last 90 days, newest first, in the user's language.
 * Alert rows carry the alert's live title and (effective) status.
 */
export async function listInbox(opts: { userId: string; language: AppLanguage; cursor?: string; limit: number; now: Date }) {
  const { userId, language, limit, now } = opts;
  const c = opts.cursor ? decodeCursor(opts.cursor) : undefined;
  const rows = await prisma.notification.findMany({
    where: {
      userId,
      createdAt: { gte: windowStart(now) },
      ...(c ? { OR: [{ createdAt: { lt: new Date(c.k) } }, { createdAt: new Date(c.k), id: { lt: c.id } }] } : {}),
    },
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    take: limit + 1,
  });
  const page = rows.slice(0, limit);
  const alertIds = page.filter((r) => r.kind === 'alert' && r.refId).map((r) => r.refId!);
  const alerts = alertIds.length
    ? await prisma.alert.findMany({
        where: { id: { in: alertIds } },
        select: { id: true, severity: true, status: true, validTo: true, titleEn: true, titleGu: true },
      })
    : [];
  const byId = new Map(alerts.map((a) => [a.id, a]));
  const gu = language === 'gu';
  const items = page.map((r) => {
    const a = r.kind === 'alert' && r.refId ? byId.get(r.refId) : undefined;
    return {
      id: r.id,
      kind: r.kind,
      refId: r.refId,
      route: r.route,
      title: a ? (gu ? a.titleGu || a.titleEn : a.titleEn) : gu ? r.titleGu : r.titleEn,
      body: gu ? r.bodyGu : r.bodyEn,
      createdAt: r.createdAt.toISOString(),
      readAt: r.readAt?.toISOString() ?? null,
      ...(a ? { alert: { severity: a.severity, status: effectiveStatus(a, now) } } : {}),
    };
  });
  const last = page[page.length - 1];
  return {
    items,
    unreadCount: await unreadCount(userId, now),
    nextCursor: rows.length > limit && last ? encodeCursor({ k: last.createdAt.toISOString(), id: last.id }) : null,
  };
}

/** POST /me/notifications/read: only the caller's rows; idempotent. */
export async function markRead(userId: string, input: z.infer<typeof markReadBody>, now: Date): Promise<number> {
  await prisma.notification.updateMany({
    where: { userId, readAt: null, ...('ids' in input ? { id: { in: input.ids } } : {}) },
    data: { readAt: now },
  });
  return unreadCount(userId, now);
}
