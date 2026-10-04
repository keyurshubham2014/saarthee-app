import { Router, type Request } from 'express';
import { z } from 'zod';
import { staffAudit } from '../../lib/audit';
import { now } from '../../lib/clock';
import { rateLimit } from '../../middleware/rateLimit';
import { requireStaff } from '../../middleware/requireStaff';
import { validate } from '../../middleware/validate';
import { approveAlert, publishAlert, retractAlert } from './approvals.service';
import { loadStaffAlert, toStaffDto } from './common';
import { createAlert, listStaffAlerts, patchAlert, submitAlert, supersedeAlert } from './drafts.service';
import { composerBody, listQuery, patchBody, retractBody, type ComposerInput, type PatchInput } from './schemas';

/** Staff alert composer and approval (TASK-08 §5.3/§5.5). Moderators and admins only. */
export const staffAlertsRouter = Router();

const actorKey = (req: Request) => `staff:${req.staff?.actorId ?? 'none'}`;
const limiter = rateLimit({ windowMs: 60_000, max: 300, keyGenerator: actorKey });
const guard = [requireStaff('moderator', 'admin'), limiter];
const idParams = z.object({ id: z.uuid() });
const idOf = (res: { locals: Record<string, unknown> }) => (res.locals.params as z.infer<typeof idParams>).id;

async function dto(id: string, extra: Record<string, unknown> = {}) {
  return toStaffDto(await loadStaffAlert(id), now(), extra);
}

staffAlertsRouter.get('/staff/alerts', ...guard, validate({ query: listQuery }), async (_req, res) => {
  res.json(await listStaffAlerts(res.locals.query as z.infer<typeof listQuery>, now()));
});

staffAlertsRouter.get('/staff/alerts/:id', ...guard, validate({ params: idParams }), async (_req, res) => {
  res.json(await dto(idOf(res)));
});

staffAlertsRouter.post('/staff/alerts', ...guard, validate({ body: composerBody }), async (req, res) => {
  const id = await createAlert(req.staff!, req.body as ComposerInput);
  staffAudit(req, 'alert_created', id);
  res.status(201).json(await dto(id));
});

staffAlertsRouter.patch('/staff/alerts/:id', ...guard, validate({ params: idParams, body: patchBody }), async (req, res) => {
  const id = idOf(res);
  await patchAlert(id, req.body as PatchInput, now());
  staffAudit(req, 'alert_updated', id);
  res.json(await dto(id));
});

staffAlertsRouter.post('/staff/alerts/:id/submit', ...guard, validate({ params: idParams }), async (req, res) => {
  const id = idOf(res);
  await submitAlert(id, now());
  staffAudit(req, 'alert_submitted', id);
  res.json(await dto(id));
});

staffAlertsRouter.post('/staff/alerts/:id/approve', ...guard, validate({ params: idParams }), async (req, res) => {
  const id = idOf(res);
  await approveAlert(req.staff!, id);
  staffAudit(req, 'alert_approved', id);
  res.json(await dto(id));
});

staffAlertsRouter.post('/staff/alerts/:id/publish', ...guard, validate({ params: idParams }), async (req, res) => {
  const id = idOf(res);
  const { delivery } = await publishAlert(req.staff!, id, now());
  staffAudit(req, 'alert_published', id, { held: delivery.held });
  res.json(await dto(id, { delivery: { held: delivery.held, ...(delivery.sendAfter ? { sendAfter: delivery.sendAfter } : {}) } }));
});

staffAlertsRouter.post('/staff/alerts/:id/retract', ...guard, validate({ params: idParams, body: retractBody }), async (req, res) => {
  const id = idOf(res);
  const { cancelPushed } = await retractAlert(req.staff!, id, (req.body as z.infer<typeof retractBody>).reason, now());
  staffAudit(req, 'alert_retracted', id, { cancelPushed });
  res.json(await dto(id));
});

staffAlertsRouter.post('/staff/alerts/:id/supersede', ...guard, validate({ params: idParams }), async (req, res) => {
  const old = idOf(res);
  const id = await supersedeAlert(req.staff!, old);
  staffAudit(req, 'alert_superseded', id, { supersedesId: old });
  res.status(201).json(await dto(id));
});
