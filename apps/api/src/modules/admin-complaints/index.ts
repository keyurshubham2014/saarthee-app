import { Router } from 'express';
import { z } from 'zod';
import { auditLog } from '../../lib/audit';
import { sendJpeg } from '../../lib/http/sendJpeg';
import { validate } from '../../middleware/validate';
import { openComplaintPhoto, openVerificationPhoto } from '../photos/read.service';
import { createReminder, revokeReminder } from '../reminders/reminders.service';
import { MSG } from '../../lib/validation';
import { listComplaints, type ComplaintFilters } from './complaints.service';
import { anonymizeComplaint, getComplaintDetail, setExclusion } from './manage.service';

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

adminComplaintsRouter.get('/complaints/:id', validate({ params: idParams }), async (_req, res) => {
  const { id } = res.locals.params as z.infer<typeof idParams>;
  res.json(await getComplaintDetail(id));
});

const exclusionBody = z
  .object({
    isExcluded: z.boolean(),
    reason: z.enum(['test', 'invalid', 'duplicate', 'other']).optional(),
    note: z.string().trim().max(500).optional(),
  })
  .refine((b) => !b.isExcluded || b.reason !== undefined, { path: ['reason'], message: MSG.reason });

adminComplaintsRouter.patch(
  '/complaints/:id/exclusion',
  validate({ params: idParams, body: exclusionBody }),
  async (req, res) => {
    const { id } = res.locals.params as z.infer<typeof idParams>;
    const body = req.body as z.infer<typeof exclusionBody>;
    const summary = await setExclusion(id, body, req.admin!.id);
    auditLog(req, 'exclusion_changed', id, { isExcluded: body.isExcluded });
    res.json(summary);
  },
);

const anonymizeBody = z.object({ confirm: z.literal(true, { error: 'Confirm to remove personal data.' }) });

adminComplaintsRouter.post(
  '/complaints/:id/anonymize',
  validate({ params: idParams, body: anonymizeBody }),
  async (req, res) => {
    const { id } = res.locals.params as z.infer<typeof idParams>;
    const result = await anonymizeComplaint(id);
    auditLog(req, 'anonymized', id);
    res.json(result);
  },
);

adminComplaintsRouter.post('/reminders/:id/revoke', validate({ params: idParams }), async (req, res) => {
  const { id } = res.locals.params as z.infer<typeof idParams>;
  const result = await revokeReminder(id);
  auditLog(req, 'reminder_revoked', id);
  res.json(result);
});
