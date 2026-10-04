import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/db';
import { AppError } from '../../lib/errors';
import { decodeCursor, encodeCursor } from '../../lib/pagination';
import { alertInclude, toAlertDetailDto, toAlertDto, type AlertDto } from './dto';

const PAST_DAYS = 30;
const DAY_MS = 86_400_000;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

interface ActiveCursor {
  crit: 0 | 1;
  vf: string;
  id: string;
}

function encodeActive(c: ActiveCursor): string {
  return Buffer.from(JSON.stringify([c.crit, c.vf, c.id]), 'utf8').toString('base64url');
}

function decodeActive(raw: string): ActiveCursor {
  try {
    const [crit, vf, id] = JSON.parse(Buffer.from(raw, 'base64url').toString('utf8')) as unknown[];
    if ((crit === 0 || crit === 1) && typeof vf === 'string' && !Number.isNaN(Date.parse(vf)) && typeof id === 'string' && UUID.test(id)) {
      return { crit, vf, id };
    }
  } catch {
    // fall through
  }
  throw new AppError('VALIDATION_FAILED', { details: [{ field: 'cursor', issue: 'Invalid cursor.' }] });
}

async function loadInOrder(ids: string[], now: Date): Promise<AlertDto[]> {
  if (ids.length === 0) return [];
  const rows = await prisma.alert.findMany({ where: { id: { in: ids } }, include: alertInclude });
  const byId = new Map(rows.map((r) => [r.id, r]));
  return ids.map((id) => toAlertDto(byId.get(id)!, now));
}

/**
 * GET /alerts (§5.3): active = published and valid_to > now, Critical first then valid_from; past =
 * ended (expired, retracted, or published past valid_to) in the last 30 days, newest first.
 */
export async function listAlerts(opts: { wardIds: string[]; active: boolean; cursor?: string; limit: number; now: Date }) {
  const { wardIds, active, limit, now } = opts;
  const inWards = Prisma.sql`EXISTS (SELECT 1 FROM alert_wards aw WHERE aw.alert_id = a.id AND aw.ward_id = ANY(${wardIds}::uuid[]))`;
  if (active) {
    const c = opts.cursor ? decodeActive(opts.cursor) : undefined;
    const after = c
      ? Prisma.sql`AND ((a.severity = 'critical')::int < ${c.crit} OR ((a.severity = 'critical')::int = ${c.crit} AND (a.valid_from, a.id) > (${new Date(c.vf)}, ${c.id}::uuid)))`
      : Prisma.empty;
    const rows = await prisma.$queryRaw<{ id: string; crit: number; valid_from: Date }[]>`
      SELECT a.id, (a.severity = 'critical')::int AS crit, a.valid_from FROM alerts a
      WHERE a.status = 'published' AND a.valid_to > ${now} AND ${inWards} ${after}
      ORDER BY crit DESC, a.valid_from ASC, a.id ASC LIMIT ${limit + 1}`;
    const page = rows.slice(0, limit);
    const last = page[page.length - 1];
    const nextCursor = rows.length > limit && last ? encodeActive({ crit: last.crit ? 1 : 0, vf: last.valid_from.toISOString(), id: last.id }) : null;
    return { items: await loadInOrder(page.map((r) => r.id), now), nextCursor };
  }
  const c = opts.cursor ? decodeCursor(opts.cursor) : undefined;
  const endedAt = Prisma.sql`(CASE WHEN a.status = 'retracted' THEN a.retracted_at ELSE a.valid_to END)`;
  const after = c ? Prisma.sql`AND (${endedAt}, a.id) < (${new Date(c.k)}, ${c.id}::uuid)` : Prisma.empty;
  const rows = await prisma.$queryRaw<{ id: string; ended_at: Date }[]>`
    SELECT a.id, ${endedAt} AS ended_at FROM alerts a
    WHERE (a.status IN ('expired', 'retracted') OR (a.status = 'published' AND a.valid_to <= ${now}))
      AND a.published_at IS NOT NULL AND ${endedAt} >= ${new Date(now.getTime() - PAST_DAYS * DAY_MS)} AND ${inWards} ${after}
    ORDER BY ended_at DESC, a.id DESC LIMIT ${limit + 1}`;
  const page = rows.slice(0, limit);
  const last = page[page.length - 1];
  const nextCursor = rows.length > limit && last ? encodeCursor({ k: last.ended_at.toISOString(), id: last.id }) : null;
  return { items: await loadInOrder(page.map((r) => r.id), now), nextCursor };
}

/** GET /alerts/{id}: drafts and pending alerts are 404 publicly. */
export async function getPublicAlert(id: string, now: Date) {
  const a = await prisma.alert.findUnique({ where: { id }, include: alertInclude });
  if (!a || a.status === 'draft' || a.status === 'pending_approval') throw new AppError('NOT_FOUND');
  return toAlertDetailDto(a, now);
}
