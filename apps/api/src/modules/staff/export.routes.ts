/**
 * Staff CSV exports (TASK-10 §5.3, REQ-F-052): issues, issue events, verifications. Reporters appear as an
 * HMAC `reporter_ref`; the phone column appears only when an admin includes it with a reason (audited).
 * Cells go through the v1 csv helper (formula-injection escaping). Over EXPORT_MAX_ROWS → 413.
 */
import { createHmac } from 'node:crypto';
import { Router } from 'express';
import { Prisma } from '@prisma/client';
import { z } from 'zod';
import { config } from '../../config';
import { auditStaff } from '../../lib/audit';
import { csvRow, type CsvValue } from '../../lib/csv';
import { prisma } from '../../lib/db';
import { AppError } from '../../lib/errors';
import { validate } from '../../middleware/validate';
import { admins } from './common';

export const exportRouter = Router();

const DAY = 86_400_000;
const exportQuery = z
  .object({
    dataset: z.enum(['issues', 'issue_events', 'verifications']),
    from: z.iso.date(),
    to: z.iso.date(),
    ward: z.uuid().optional(),
    includePhone: z.enum(['true', 'false']).default('false').transform((v) => v === 'true'),
    reason: z.string().trim().optional(),
  })
  .superRefine((q, ctx) => {
    const span = (Date.parse(q.to) - Date.parse(q.from)) / DAY;
    if (span < 0) ctx.addIssue({ code: 'custom', path: ['to'], message: 'must be on or after from' });
    if (span > 366) ctx.addIssue({ code: 'custom', path: ['to'], message: 'range must be 366 days or less' });
    if (q.includePhone && (!q.reason || q.reason.length < 10 || q.reason.length > 200)) {
      ctx.addIssue({ code: 'custom', path: ['reason'], message: 'a reason of 10–200 characters is required to include phone numbers' });
    }
  });
type ExportQuery = z.infer<typeof exportQuery>;

const secret = () => config.EXPORT_HMAC_SECRET ?? `export:${config.JWT_SECRET}`;
export const reporterRef = (userId: string | null) =>
  userId ? createHmac('sha256', secret()).update(userId).digest('hex').slice(0, 16) : '';

/** IST date range [from 00:00, to+1 00:00). */
const range = (q: ExportQuery) => ({ from: new Date(`${q.from}T00:00:00+05:30`), to: new Date(Date.parse(`${q.to}T00:00:00+05:30`) + DAY) });

async function build(q: ExportQuery): Promise<{ header: string[]; rows: CsvValue[][] }> {
  const { from, to } = range(q);
  const ward = q.ward ? Prisma.sql`AND i.ward_id = ${q.ward}::uuid` : Prisma.empty;
  const phone = q.includePhone;
  const limit = config.EXPORT_MAX_ROWS + 1;
  if (q.dataset === 'issues') {
    const rows = await prisma.$queryRaw<Record<string, CsvValue>[]>`
      SELECT i.id, i.created_at, i.status::text AS status, c.slug AS category, w.number AS ward_number, w.name_en AS ward_name,
             i.title, i.lat, i.lng, i.me_too_count, i.follower_count, i.sla_due_at, i.status_changed_at,
             i.visibility::text AS visibility, i.ccrs_number, i.reporter_id, u.phone_e164
      FROM issues i JOIN categories c ON c.id = i.category_id LEFT JOIN wards w ON w.id = i.ward_id
      LEFT JOIN users u ON u.id = i.reporter_id
      WHERE i.created_at >= ${from} AND i.created_at < ${to} ${ward}
      ORDER BY i.created_at LIMIT ${limit}`;
    const header = ['id', 'created_at', 'status', 'category', 'ward_number', 'ward_name', 'title', 'lat', 'lng', 'me_too_count', 'follower_count', 'sla_due_at', 'status_changed_at', 'visibility', 'ccrs_number', 'reporter_ref'];
    return {
      header: phone ? [...header, 'reporter_phone'] : header,
      rows: rows.map((r) => {
        const base = header.slice(0, -1).map((h) => r[h]);
        base.push(reporterRef(r.reporter_id as string | null));
        return phone ? [...base, r.phone_e164] : base;
      }),
    };
  }
  if (q.dataset === 'issue_events') {
    const rows = await prisma.$queryRaw<Record<string, CsvValue>[]>`
      SELECT e.id, e.issue_id, e.created_at, e.type::text AS type, e.from_status::text AS from_status, e.to_status::text AS to_status,
             e.actor_role::text AS actor_role
      FROM issue_events e JOIN issues i ON i.id = e.issue_id
      WHERE e.created_at >= ${from} AND e.created_at < ${to} ${ward}
      ORDER BY e.created_at LIMIT ${limit}`;
    const header = ['id', 'issue_id', 'created_at', 'type', 'from_status', 'to_status', 'actor_role'];
    return { header, rows: rows.map((r) => header.map((h) => r[h])) };
  }
  const rows = await prisma.$queryRaw<Record<string, CsvValue>[]>`
    SELECT v.id, v.issue_id, v.created_at, v.answer::text AS answer, v.distance_m, v.user_id, u.phone_e164
    FROM issue_verifications v JOIN issues i ON i.id = v.issue_id LEFT JOIN users u ON u.id = v.user_id
    WHERE v.created_at >= ${from} AND v.created_at < ${to} ${ward}
    ORDER BY v.created_at LIMIT ${limit}`;
  const header = ['id', 'issue_id', 'created_at', 'answer', 'distance_m', 'verifier_ref'];
  return {
    header: phone ? [...header, 'verifier_phone'] : header,
    rows: rows.map((r) => {
      const base: CsvValue[] = [r.id, r.issue_id, r.created_at, r.answer, r.distance_m, reporterRef(r.user_id as string)];
      return phone ? [...base, r.phone_e164] : base;
    }),
  };
}

exportRouter.get('/staff/export', ...admins, validate({ query: exportQuery }), async (req, res) => {
  const q = res.locals.query as ExportQuery;
  const { header, rows } = await build(q);
  if (rows.length > config.EXPORT_MAX_ROWS) throw new AppError('EXPORT_TOO_LARGE');
  auditStaff(req, 'export_downloaded', { targetType: 'export', targetId: q.dataset, extra: { dataset: q.dataset, rows: rows.length, includePhone: q.includePhone } });
  res.setHeader('Content-Type', 'text/csv; charset=utf-8');
  res.setHeader('Content-Disposition', `attachment; filename="saarthee-${q.dataset}-${q.from}-to-${q.to}.csv"`);
  res.setHeader('Cache-Control', 'no-store');
  res.write(csvRow(header));
  for (let i = 0; i < rows.length; i += 500) res.write(rows.slice(i, i + 500).map(csvRow).join(''));
  res.end();
});
