/**
 * Issues module, TASK-05 part (V2 TASK-05 §5.3): GET /issues/nearby, POST /issues, POST /issues/{id}/me-too,
 * POST /issues/{id}/ccrs. TASK-06/07 add status, detail, lists and follows to this module.
 */
import { Router } from 'express';
import type { z } from 'zod';
import { rateLimit } from '../../middleware/rateLimit';
import { requireUser } from '../../middleware/requireUser';
import { validate } from '../../middleware/validate';
import { addMeToo, linkCcrs, nearby } from './engage.service';
import { createIssueBody, issueIdParams, linkCcrsBody, nearbyQuery, type CreateIssueBody } from './issues.schemas';
import { createIssue } from './issues.service';

export const issuesRouter = Router();

const nearbyLimiter = rateLimit({ windowMs: 60_000, max: 120 });
const ccrsLimiter = rateLimit({ windowMs: 24 * 60 * 60_000, max: 20, keyGenerator: (req) => `ccrs:${req.user?.id ?? 'anon'}` });

issuesRouter.get('/issues/nearby', nearbyLimiter, validate({ query: nearbyQuery }), async (_req, res) => {
  const q = res.locals.query as z.infer<typeof nearbyQuery>;
  res.json({ items: await nearby(q.lat, q.lng, q.category) });
});

issuesRouter.post('/issues', requireUser, validate({ body: createIssueBody }), async (req, res) => {
  const result = await createIssue(req.user!, req.body as CreateIssueBody, { res });
  res.status(result.created ? 201 : 200).json(result.body);
});

issuesRouter.post('/issues/:id/me-too', requireUser, validate({ params: issueIdParams }), async (req, res) => {
  const { id } = res.locals.params as z.infer<typeof issueIdParams>;
  const r = await addMeToo(req.user!.id, id, res);
  res.status(r.created ? 201 : 200).json({ meTooCount: r.meTooCount });
});

issuesRouter.post('/issues/:id/ccrs', requireUser, ccrsLimiter, validate({ params: issueIdParams, body: linkCcrsBody }), async (req, res) => {
  const { id } = res.locals.params as z.infer<typeof issueIdParams>;
  const b = req.body as z.infer<typeof linkCcrsBody>;
  res.json(await linkCcrs(req.user!.id, id, b.ccrsNumber, b.filedVia));
});
