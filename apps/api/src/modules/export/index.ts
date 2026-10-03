import { Router } from 'express';
import { z } from 'zod';
import { auditLog } from '../../lib/audit';
import { validate } from '../../middleware/validate';
import { buildExport, type ExportType } from './export.service';

/** Mounted on the /admin router. */
export const exportRouter = Router();

const exportQuery = z.object({
  type: z.enum(['complaints', 'verifications', 'reminders']),
  includePhone: z
    .enum(['true', 'false'])
    .default('false')
    .transform((v) => v === 'true'),
});

function stamp(d: Date): string {
  // IST timestamp for the file name (the app shows IST).
  const ist = new Date(d.getTime() + 330 * 60_000).toISOString();
  return `${ist.slice(0, 10).replace(/-/g, '')}-${ist.slice(11, 16).replace(':', '')}`;
}

exportRouter.get('/export', validate({ query: exportQuery }), async (req, res) => {
  const { type, includePhone } = res.locals.query as { type: ExportType; includePhone: boolean };
  const csv = await buildExport(type, includePhone);
  // Logged: admin, type, includePhone — never the contents.
  auditLog(req, 'export', null, { type, includePhone });
  res.setHeader('Content-Type', 'text/csv; charset=utf-8');
  res.setHeader('Content-Disposition', `attachment; filename="saarthee-${type}-${stamp(new Date())}.csv"`);
  res.setHeader('Cache-Control', 'no-store');
  res.send(csv);
});
