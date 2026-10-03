import { Prisma, type SourceTag } from '@prisma/client';
import { config } from '../../config';
import { prisma } from '../../lib/db';
import { decodeCursor, encodeCursor } from '../../lib/pagination';

export type ComplaintStatus = 'filed' | 'reminded' | 'verified_fixed' | 'verified_not_fixed';

export interface ComplaintFilters {
  source?: SourceTag;
  categoryId?: string;
  status?: ComplaintStatus;
  due?: boolean;
  excluded: 'true' | 'false' | 'all';
  ccrsDuplicate?: boolean;
  cursor?: string;
  limit: number;
}

/** Admin list item (03 §2.3). Deliberately has no phone field. */
export interface ComplaintSummary {
  id: string;
  createdAt: string;
  sourceTag: string;
  categoryName: string;
  ccrsNumber: string;
  groupLabel: string | null;
  ccrsDuplicate: boolean;
  status: ComplaintStatus;
  isDue: boolean;
  reminderCount: number;
  lastReminderAt: string | null;
  verificationCount: number;
  latestResult: 'fixed' | 'not_fixed' | null;
  latestVerifiedAt: string | null;
  isExcluded: boolean;
  exclusionReason: string | null;
  anonymized: boolean;
}

interface Row {
  id: string;
  created_at: Date;
  source_tag: string;
  category_name: string;
  ccrs_number_raw: string;
  group_label: string | null;
  ccrs_duplicate_flag: boolean;
  status: ComplaintStatus;
  is_due: boolean;
  reminder_count: number;
  last_reminder_at: Date | null;
  verification_count: number;
  latest_result: 'fixed' | 'not_fixed' | null;
  latest_verified_at: Date | null;
  is_excluded: boolean;
  exclusion_reason: string | null;
  anonymized_at: Date | null;
  due_reference_at: Date;
}

const iso = (d: Date | null) => (d ? d.toISOString() : null);

/** Explicit allow-list mapper — only these fields ever leave the API. */
function toSummary(r: Row): ComplaintSummary {
  return {
    id: r.id,
    createdAt: r.created_at.toISOString(),
    sourceTag: r.source_tag,
    categoryName: r.category_name,
    ccrsNumber: r.ccrs_number_raw,
    groupLabel: r.group_label,
    ccrsDuplicate: r.ccrs_duplicate_flag,
    status: r.status,
    isDue: r.is_due,
    reminderCount: r.reminder_count,
    lastReminderAt: iso(r.last_reminder_at),
    verificationCount: r.verification_count,
    latestResult: r.latest_result,
    latestVerifiedAt: iso(r.latest_verified_at),
    isExcluded: r.is_excluded,
    exclusionReason: r.exclusion_reason,
    anonymized: r.anonymized_at !== null,
  };
}

/** Due rule (03 §4.3) with REMINDER_INTERVAL_DAYS bound as a query parameter. */
function dueExpr(): Prisma.Sql {
  return Prisma.sql`(NOT s.is_excluded AND s.anonymized_at IS NULL AND s.verification_count = 0
    AND s.due_reference_at < now() - make_interval(days => ${config.REMINDER_INTERVAL_DAYS}::int))`;
}

function selectFrom(): Prisma.Sql {
  return Prisma.sql`
    SELECT s.complaint_id AS id, s.created_at, s.source_tag::text AS source_tag, cat.name AS category_name,
           c.ccrs_number_raw, ic.group_label, s.ccrs_duplicate_flag, s.status, ${dueExpr()} AS is_due,
           s.reminder_count, s.last_reminder_at, s.verification_count, s.latest_result::text AS latest_result,
           s.latest_verified_at, s.is_excluded, c.exclusion_reason::text AS exclusion_reason, s.anonymized_at,
           s.due_reference_at
    FROM complaint_status_v s
    JOIN complaints c ON c.id = s.complaint_id
    JOIN ccrs_categories cat ON cat.id = c.category_id
    LEFT JOIN invite_codes ic ON ic.id = c.invite_code_id`;
}

/**
 * Lists complaints with derived status. Default order createdAt DESC, id DESC; the Due list (due=true)
 * is ordered oldest-due first (due_reference_at ASC, id ASC). Cursor = opaque (sortKey, id).
 */
export async function listComplaints(f: ComplaintFilters): Promise<{ items: ComplaintSummary[]; nextCursor: string | null }> {
  const where: Prisma.Sql[] = [];
  if (f.source) where.push(Prisma.sql`s.source_tag = ${f.source}::source_tag`);
  if (f.categoryId) where.push(Prisma.sql`s.category_id = ${f.categoryId}::uuid`);
  if (f.status) where.push(Prisma.sql`s.status = ${f.status}`);
  if (f.due === true) where.push(dueExpr());
  if (f.due === false) where.push(Prisma.sql`NOT ${dueExpr()}`);
  if (f.excluded !== 'all') where.push(Prisma.sql`s.is_excluded = ${f.excluded === 'true'}`);
  if (f.ccrsDuplicate !== undefined) where.push(Prisma.sql`s.ccrs_duplicate_flag = ${f.ccrsDuplicate}`);

  const dueOrder = f.due === true;
  if (f.cursor) {
    const c = decodeCursor(f.cursor);
    const k = new Date(c.k);
    where.push(
      dueOrder
        ? Prisma.sql`(s.due_reference_at, s.complaint_id) > (${k}::timestamptz, ${c.id}::uuid)`
        : Prisma.sql`(s.created_at, s.complaint_id) < (${k}::timestamptz, ${c.id}::uuid)`,
    );
  }
  const whereSql = where.length ? Prisma.sql`WHERE ${Prisma.join(where, ' AND ')}` : Prisma.empty;
  const order = dueOrder
    ? Prisma.sql`ORDER BY s.due_reference_at ASC, s.complaint_id ASC`
    : Prisma.sql`ORDER BY s.created_at DESC, s.complaint_id DESC`;

  const rows = await prisma.$queryRaw<Row[]>`${selectFrom()} ${whereSql} ${order} LIMIT ${f.limit + 1}`;
  const page = rows.slice(0, f.limit);
  const last = page[page.length - 1];
  const nextCursor =
    rows.length > f.limit && last
      ? encodeCursor({ k: (dueOrder ? last.due_reference_at : last.created_at).toISOString(), id: last.id })
      : null;
  return { items: page.map(toSummary), nextCursor };
}

/** One complaint as a ComplaintSummary (used after exclusion changes). */
export async function getComplaintSummary(id: string): Promise<ComplaintSummary | null> {
  const rows = await prisma.$queryRaw<Row[]>`${selectFrom()} WHERE s.complaint_id = ${id}::uuid`;
  return rows[0] ? toSummary(rows[0]) : null;
}
