import { Router } from 'express';
import { z } from 'zod';
import { auditLog } from '../../lib/audit';
import { sendJpeg } from '../../lib/http/sendJpeg';
import { validate } from '../../middleware/validate';
import { openComplaintPhoto, openVerificationPhoto } from '../photos/read.service';
import { createReminder, revokeReminder } from '../reminders/reminders.service';
import { listComplaints, type ComplaintFilters } from './complaints.service';

/** Mounted on the /admin router (JWT guard + per-admin limiter inherited). */
export const adminComplaintsRouter = Router();

const bool = z.enum(['true', 'false']).transform((v) => v === 'true');
const idParams = z.object({ id: z.uuid() });

const listQuery = z.object({
  source: z.enum(['rwa', 'activist', 'social', 'network', 'unknown']).optional(),
  categoryId: z.uuid().optional(),
  status: z.enum(['filed', 'reminded', 'verified_fixed', 'verified_not_fixed']).optional(),
  due: bool.optional(),
  excluded: z.enum(['true', 'false', 'all']).default('false'),
  ccrsDuplicate: bool.optional(),
  cursor: z.string().min(1).max(500).optional(),
  limit: z.coerce.number().int().min(1).max(200).default(50),
});

adminComplaintsRouter.get('/complaints', validate({ query: listQuery }), async (_req, res) => {
  res.json(await listComplaints(res.locals.query as ComplaintFilters));
});

adminComplaintsRouter.get('/complaints/:id/photo', validate({ params: idParams }), async (_req, res) => {
  const { id } = res.locals.params as z.infer<typeof idParams>;
  await sendJpeg(res, await openComplaintPhoto(id));
});

adminComplaintsRouter.get('/verifications/:id/photo', validate({ params: idParams }), async (_req, res) => {
  const { id } = res.locals.params as z.infer<typeof idParams>;
  await sendJpeg(res, await openVerificationPhoto(id));
});

adminComplaintsRouter.post('/complaints/:id/reminders', validate({ params: idParams }), async (req, res) => {
  const { id } = res.locals.params as z.infer<typeof idParams>;
  const result = await createReminder(req.admin!.id, id);
  auditLog(req, 'reminder_created', id, { reminderId: result.reminderId });
  res.status(201).json(result);
});

adminComplaintsRouter.post('/reminders/:id/revoke', validate({ params: idParams }), async (req, res) => {
  const { id } = res.locals.params as z.infer<typeof idParams>;
  const result = await revokeReminder(id);
  auditLog(req, 'reminder_revoked', id);
  res.json(result);
});
