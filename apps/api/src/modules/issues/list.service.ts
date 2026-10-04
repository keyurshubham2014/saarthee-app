/**
 * GET /issues (V2 TASK-07 §5.3, REQ-F-034, REQ-N-011): filters, three sorts and opaque keyset cursors.
 * Cursor = base64url JSON `{s, k, m?, id}`; timestamps travel as Postgres text so microseconds survive.
 */
import { Prisma } from '@prisma/client';
import { config } from '../../config';
import { now as clockNow } from '../../lib/clock';
import { prisma } from '../../lib/db';
import { AppError } from '../../lib/errors';
import type { Bbox, ListQuery, StatusFilter } from './list.schemas';
import { CARD_COLUMNS, toCard, type Card, type CardRow, type Lang } from './public';

const OPEN = ['reported', 'sent', 'acknowledged', 'in_progress', 'reopened'];
type Sort = ListQuery['sort'];

interface Cursor {
  s: Sort;
  k: string;
  m?: number;
  id: string;
}

export function encodeCursor(c: Cursor): string {
  return Buffer.from(JSON.stringify(c)).toString('base64url');
}

/** Postgres timestamptz text, e.g. `2026-10-04 14:15:41.123456+00`. */
const TS_KEY = /^\d{4}-\d\d-\d\d[ T]\d\d:\d\d:\d\d(\.\d{1,6})?([+-]\d\d(:?\d\d)?|Z)$/;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function decodeCursor(raw: string, sort: Sort): Cursor {
  try {
    const c = JSON.parse(Buffer.from(raw, 'base64url').toString('utf8')) as Cursor;
    const okM = sort !== 'most_affected' || Number.isInteger(c.m);
    if (c.s === sort && typeof c.k === 'string' && TS_KEY.test(c.k) && UUID.test(c.id) && okM) return c;
  } catch {
    // fall through
  }
  throw new AppError('VALIDATION_FAILED', { details: [{ field: 'cursor', issue: 'This list position is no longer valid. Start again.' }] });
}

/** Status filter: plain statuses, plus `overdue` and `fixed_unverified` (derived, TASK-06). OR-ed. */
export function statusSql(filters: StatusFilter[], now: Date): Prisma.Sql {
  const plain = filters.filter((f) => f !== 'overdue' && f !== 'fixed_unverified');
  const parts: Prisma.Sql[] = [];
  if (plain.length) parts.push(Prisma.sql`i.status::text IN (${Prisma.join(plain)})`);
  if (filters.includes('overdue')) parts.push(Prisma.sql`(i.status::text IN (${Prisma.join(OPEN)}) AND i.sla_due_at < ${now})`);
  if (filters.includes('fixed_unverified')) {
    const cutoff = new Date(now.getTime() - config.REOPEN_WINDOW_DAYS * 86_400_000);
    parts.push(Prisma.sql`(i.status = 'marked_fixed' AND i.marked_fixed_at < ${cutoff})`);
  }
  return Prisma.sql`(${Prisma.join(parts, ' OR ')})`;
}

export const bboxSql = (b: Bbox) =>
  Prisma.sql`i.location::geometry && ST_MakeEnvelope(${b.minLng}, ${b.minLat}, ${b.maxLng}, ${b.maxLat}, 4326)`;

/** Visibility: public, not rejected/merged — unless `mine` (own issues of any kind). */
export function baseWhere(q: { ward?: string; category?: string[]; status?: StatusFilter[]; bbox?: Bbox; mine?: boolean; following?: boolean }, userId: string | undefined, now: Date): Prisma.Sql[] {
  const w: Prisma.Sql[] = [];
  if (q.mine) w.push(Prisma.sql`i.reporter_id = ${userId}::uuid`);
  else w.push(Prisma.sql`i.visibility = 'public'`, Prisma.sql`i.status NOT IN ('rejected', 'merged')`);
  if (q.following) w.push(Prisma.sql`EXISTS (SELECT 1 FROM follows f WHERE f.issue_id = i.id AND f.user_id = ${userId}::uuid)`);
  if (q.ward) w.push(Prisma.sql`i.ward_id = ${q.ward}::uuid`);
  if (q.category?.length) w.push(Prisma.sql`c.slug IN (${Prisma.join(q.category)})`);
  if (q.status?.length) w.push(statusSql(q.status, now));
  if (q.bbox) w.push(bboxSql(q.bbox));
  return w;
}

interface ListRow extends CardRow {
  created_key: string;
  sla_key: string;
}

export async function listIssues(q: ListQuery, userId: string | undefined): Promise<{ items: Card[]; nextCursor: string | null }> {
  if ((q.mine || q.following) && !userId) throw new AppError('AUTH_REQUIRED');
  const now = clockNow();
  const where = baseWhere(q, userId, now);
  const cur = q.cursor ? decodeCursor(q.cursor, q.sort) : null;
  let order: Prisma.Sql;
  if (q.sort === 'newest') {
    order = Prisma.sql`i.created_at DESC, i.id DESC`;
    if (cur) where.push(Prisma.sql`(i.created_at, i.id) < (${cur.k}::timestamptz, ${cur.id}::uuid)`);
  } else if (q.sort === 'most_affected') {
    order = Prisma.sql`i.me_too_count DESC, i.created_at DESC, i.id DESC`;
    if (cur) where.push(Prisma.sql`(i.me_too_count, i.created_at, i.id) < (${cur.m}::int, ${cur.k}::timestamptz, ${cur.id}::uuid)`);
  } else {
    order = Prisma.sql`i.sla_due_at ASC, i.id ASC`;
    where.push(Prisma.sql`i.status::text IN (${Prisma.join(OPEN)})`, Prisma.sql`i.sla_due_at < ${now}`);
    if (cur) where.push(Prisma.sql`(i.sla_due_at, i.id) > (${cur.k}::timestamptz, ${cur.id}::uuid)`);
  }
  const rows = await prisma.$queryRaw<ListRow[]>`
    SELECT ${CARD_COLUMNS}, i.created_at::text AS created_key, i.sla_due_at::text AS sla_key
    FROM issues i
    JOIN categories c ON c.id = i.category_id
    LEFT JOIN wards w ON w.id = i.ward_id
    WHERE ${Prisma.join(where, ' AND ')}
    ORDER BY ${order}
    LIMIT ${q.limit + 1}`;
  const page = rows.slice(0, q.limit);
  const last = page[page.length - 1];
  const nextCursor =
    rows.length > q.limit && last
      ? encodeCursor({ s: q.sort, k: q.sort === 'overdue' ? last.sla_key : last.created_key, m: q.sort === 'most_affected' ? Number(last.me_too_count) : undefined, id: last.id })
      : null;
  return { items: page.map((r) => toCard(r, q.lang as Lang)), nextCursor };
}
