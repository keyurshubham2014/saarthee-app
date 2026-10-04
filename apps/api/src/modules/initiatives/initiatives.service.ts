import type { Initiative, Prisma, UserRole } from '@prisma/client';
import { prisma } from '../../lib/db';
import { AppError } from '../../lib/errors';
import { decodeCursor, encodeCursor } from '../../lib/pagination';

export type RsvpStatus = 'going' | 'cancelled' | 'attended';

const notFound = () => new AppError('NOT_FOUND', { message: 'This drive is no longer listed.' });

/** Public list fields (TASK-12 §5.3 `GET /initiatives`). */
export function listItem(i: Initiative, myRsvp: string | null) {
  return {
    id: i.id,
    titleEn: i.titleEn,
    titleGu: i.titleGu,
    type: i.type,
    organiser: i.organiser,
    organiserName: i.organiserName,
    wardId: i.wardId,
    locationTextEn: i.locationTextEn,
    locationTextGu: i.locationTextGu,
    startsAt: i.startsAt,
    endsAt: i.endsAt,
    capacity: i.capacity,
    goingCount: i.goingCount,
    status: i.status,
    myRsvp,
  };
}

export function detail(i: Initiative, myRsvp: string | null) {
  return {
    ...listItem(i, myRsvp),
    descriptionEn: i.descriptionEn,
    descriptionGu: i.descriptionGu,
    sourceUrl: i.sourceUrl,
    lat: i.lat === null ? null : Number(i.lat),
    lng: i.lng === null ? null : Number(i.lng),
  };
}

async function myRsvps(userId: string | undefined, ids: string[]): Promise<Map<string, string>> {
  if (!userId || ids.length === 0) return new Map();
  const rows = await prisma.rsvp.findMany({ where: { userId, initiativeId: { in: ids } }, select: { initiativeId: true, status: true } });
  return new Map(rows.map((r) => [r.initiativeId, r.status]));
}

export interface ListOpts {
  ward?: string;
  upcoming: boolean;
  type?: string;
  cursor?: string;
  limit: number;
}

/** Published drives sorted by start; `upcoming` = not yet ended; `ward` = that ward + city-wide. */
export async function listInitiatives(opts: ListOpts, userId?: string) {
  const and: Prisma.InitiativeWhereInput[] = [{ status: 'published' }];
  if (opts.upcoming) and.push({ endsAt: { gt: new Date() } });
  if (opts.type) and.push({ type: opts.type });
  if (opts.ward) and.push({ OR: [{ wardId: opts.ward }, { wardId: null }] });
  if (opts.cursor) {
    const c = decodeCursor(opts.cursor);
    const k = new Date(c.k);
    and.push({ OR: [{ startsAt: { gt: k } }, { startsAt: k, id: { gt: c.id } }] });
  }
  const rows = await prisma.initiative.findMany({
    where: { AND: and },
    orderBy: [{ startsAt: 'asc' }, { id: 'asc' }],
    take: opts.limit + 1,
  });
  const page = rows.slice(0, opts.limit);
  const mine = await myRsvps(userId, page.map((r) => r.id));
  const last = page[page.length - 1];
  return {
    items: page.map((r) => listItem(r, mine.get(r.id) ?? null)),
    nextCursor: rows.length > opts.limit && last ? encodeCursor({ k: last.startsAt.toISOString(), id: last.id }) : null,
  };
}

const STAFF: UserRole[] = ['admin', 'moderator'];

/** Detail; drafts are 404 for everyone but staff. */
export async function getInitiative(id: string, user?: { id: string; role: UserRole }) {
  const i = await prisma.initiative.findUnique({ where: { id } });
  if (!i || (i.status === 'draft' && !(user && STAFF.includes(user.role)))) throw notFound();
  const mine = await myRsvps(user?.id, [id]);
  return detail(i, mine.get(id) ?? null);
}

async function lockInitiative(tx: Prisma.TransactionClient, id: string): Promise<Initiative> {
  const locked = await tx.$queryRaw<{ id: string }[]>`SELECT id FROM initiatives WHERE id = ${id}::uuid FOR UPDATE`;
  if (locked.length === 0) throw notFound();
  return tx.initiative.findUniqueOrThrow({ where: { id } });
}

/** POST /initiatives/{id}/rsvp: idempotent; the row lock keeps going_count ≤ capacity under concurrency. */
export async function rsvp(id: string, userId: string) {
  return prisma.$transaction(async (tx) => {
    const i = await lockInitiative(tx, id);
    if (i.status === 'draft') throw notFound();
    const existing = await tx.rsvp.findUnique({ where: { initiativeId_userId: { initiativeId: id, userId } } });
    if (existing && existing.status !== 'cancelled') return { status: 'going' as const, goingCount: i.goingCount };
    if (i.status !== 'published' || i.startsAt <= new Date()) throw new AppError('INITIATIVE_NOT_OPEN');
    if (i.capacity !== null && i.goingCount >= i.capacity) throw new AppError('INITIATIVE_FULL');
    await tx.rsvp.upsert({
      where: { initiativeId_userId: { initiativeId: id, userId } },
      create: { initiativeId: id, userId, status: 'going' },
      update: { status: 'going', attendanceMarkedBy: null },
    });
    const updated = await tx.initiative.update({ where: { id }, data: { goingCount: { increment: 1 } }, select: { goingCount: true } });
    return { status: 'going' as const, goingCount: updated.goingCount };
  });
}

/** DELETE /initiatives/{id}/rsvp: idempotent; not allowed once the drive has started. */
export async function cancelRsvp(id: string, userId: string) {
  return prisma.$transaction(async (tx) => {
    const i = await lockInitiative(tx, id);
    if (i.status === 'draft') throw notFound();
    if (i.startsAt <= new Date()) throw new AppError('INITIATIVE_STARTED');
    const existing = await tx.rsvp.findUnique({ where: { initiativeId_userId: { initiativeId: id, userId } } });
    if (!existing || existing.status === 'cancelled') return { status: 'cancelled' as const, goingCount: i.goingCount };
    await tx.rsvp.update({ where: { initiativeId_userId: { initiativeId: id, userId } }, data: { status: 'cancelled' } });
    const updated = await tx.initiative.update({ where: { id }, data: { goingCount: { decrement: 1 } }, select: { goingCount: true } });
    return { status: 'cancelled' as const, goingCount: updated.goingCount };
  });
}
