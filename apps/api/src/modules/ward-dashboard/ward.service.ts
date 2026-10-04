/**
 * TASK-11 ward CSV export (§5.3 fixed columns, formula-safe via csvRow) and the representative ward issue list
 * with `allowedActions` from the same rule function the transition hook uses.
 */
import { Prisma, type IssueStatus } from '@prisma/client';
import { config } from '../../config';
import { csvRow, type CsvValue } from '../../lib/csv';
import { prisma } from '../../lib/db';
import { AppError } from '../../lib/errors';
import { decodeCursor, encodeCursor } from '../../lib/pagination';
import { repAllowedActions } from '../rep-claims/scope';

export const WARD_CSV_COLUMNS = [
  'issue_id', 'created_at', 'category', 'status', 'age_days', 'sla_due_at', 'overdue', 'me_too_count', 'follower_count',
  'latitude', 'longitude', 'ward_number', 'last_status_change_at', 'ccrs_linked',
] as const;

const DAY = 86_400_000;
const OPEN: IssueStatus[] = ['reported', 'sent', 'acknowledged', 'in_progress', 'reopened'];

export async function wardCsv(wardId: string, from: string, to: string, at: Date): Promise<{ csv: string; rows: number; wardNumber: number }> {
  const ward = await prisma.ward.findUnique({ where: { id: wardId }, select: { number: true } });
  if (!ward) throw new AppError('NOT_FOUND');
  const start = new Date(`${from}T00:00:00+05:30`);
  const end = new Date(Date.parse(`${to}T00:00:00+05:30`) + DAY);
  const rows = await prisma.$queryRaw<{ id: string; created_at: Date; slug: string; status: IssueStatus; sla_due_at: Date; me_too_count: number; follower_count: number; lat: Prisma.Decimal; lng: Prisma.Decimal; status_changed_at: Date; ccrs: boolean }[]>`
    SELECT i.id::text, i.created_at, c.slug, i.status, i.sla_due_at, i.me_too_count, i.follower_count, i.lat, i.lng,
           i.status_changed_at, (i.ccrs_number IS NOT NULL) AS ccrs
    FROM issues i JOIN categories c ON c.id = i.category_id
    WHERE i.ward_id = ${wardId}::uuid AND i.visibility <> 'hidden' AND i.status NOT IN ('rejected','merged')
      AND i.created_at >= ${start} AND i.created_at < ${end}
    ORDER BY i.created_at, i.id LIMIT ${config.EXPORT_MAX_ROWS + 1}`;
  if (rows.length > config.EXPORT_MAX_ROWS) throw new AppError('EXPORT_TOO_LARGE');
  let csv = csvRow([...WARD_CSV_COLUMNS]);
  for (const r of rows) {
    const values: CsvValue[] = [
      r.id, r.created_at, r.slug, r.status, Math.floor((at.getTime() - r.created_at.getTime()) / DAY), r.sla_due_at,
      OPEN.includes(r.status) && r.sla_due_at < at ? 'yes' : 'no', r.me_too_count, r.follower_count,
      Number(r.lat).toFixed(4), Number(r.lng).toFixed(4), ward.number, r.status_changed_at, r.ccrs ? 'yes' : 'no',
    ];
    csv += csvRow(values);
  }
  return { csv, rows: rows.length, wardNumber: ward.number };
}

export interface WardIssueQuery {
  ward: string;
  status?: IssueStatus;
  overdue?: boolean;
  cursor?: string;
  limit: number;
}

export async function wardIssues(q: WardIssueQuery, role: string, at: Date) {
  const cur = q.cursor ? decodeCursor(q.cursor) : null;
  const where: Prisma.IssueWhereInput = {
    wardId: q.ward,
    visibility: { not: 'hidden' },
    status: q.status ? q.status : { notIn: ['rejected', 'merged'] },
    ...(q.overdue ? { status: { in: OPEN }, slaDueAt: { lt: at } } : {}),
    ...(cur ? { OR: [{ createdAt: { lt: new Date(cur.k) } }, { createdAt: new Date(cur.k), id: { lt: cur.id } }] } : {}),
  };
  const items = await prisma.issue.findMany({
    where, orderBy: [{ createdAt: 'desc' }, { id: 'desc' }], take: q.limit + 1,
    select: {
      id: true, title: true, status: true, createdAt: true, slaDueAt: true, meTooCount: true, followerCount: true, statusChangedAt: true,
      category: { select: { slug: true, nameEn: true, nameGu: true, icon: true } },
    },
  });
  const page = items.slice(0, q.limit);
  const last = page[page.length - 1];
  return {
    items: page.map((i) => ({
      id: i.id, title: i.title, status: i.status, category: i.category, createdAt: i.createdAt.toISOString(),
      slaDueAt: i.slaDueAt.toISOString(), overdue: OPEN.includes(i.status) && i.slaDueAt < at, meTooCount: i.meTooCount,
      followerCount: i.followerCount, statusChangedAt: i.statusChangedAt.toISOString(),
      allowedActions: role === 'representative' ? repAllowedActions(i.status) : [],
    })),
    nextCursor: items.length > q.limit && last ? encodeCursor({ k: last.createdAt.toISOString(), id: last.id }) : null,
  };
}
