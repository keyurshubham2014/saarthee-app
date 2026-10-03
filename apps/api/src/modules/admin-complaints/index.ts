import { Router } from 'express';
import { z } from 'zod';
import { auditLog } from '../../lib/audit';
import { sendJpeg } from '../../lib/http/sendJpeg';
import { validate } from '../../middleware/validate';
import { openComplaintPhoto, openVerificationPhoto } from '../photos/read.service';
import { endpointRetired } from '../../middleware/endpointRetired';
import { listComplaints, type ComplaintFilters } from './complaints.service';
import { anonymizeComplaint, getComplaintDetail } from './manage.service';

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

// v1 pilot writes retired in v2 (Spec D11, V2 TASK-01 §5.3): reminders, exclusion, reminder revoke.
adminComplaintsRouter.post('/complaints/:id/reminders', endpointRetired);
adminComplaintsRouter.patch('/complaints/:id/exclusion', endpointRetired);
adminComplaintsRouter.post('/reminders/:id/revoke', endpointRetired);

adminComplaintsRouter.get('/complaints/:id', validate({ params: idParams }), async (_req, res) => {
  const { id } = res.locals.params as z.infer<typeof idParams>;
  res.json(await getComplaintDetail(id));
});

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
