import { Router } from 'express';
import { endpointRetired } from '../../middleware/endpointRetired';
import { listCategories, listInviteCodes } from './reference.service';

/**
 * v1 invite codes and CCRS categories (03 §2.2 admin reference data). Mounted on the /admin router.
 * v2: reads kept as history; writes retired with 410 (Spec D11, V2 TASK-01 §5.3). v2 categories are
 * managed under /staff/categories (TASK-10).
 */
export const referenceRouter = Router();

referenceRouter.get('/invite-codes', async (_req, res) => {
  res.json({ items: await listInviteCodes() });
});

referenceRouter.post('/invite-codes', endpointRetired);
referenceRouter.patch('/invite-codes/:id', endpointRetired);

referenceRouter.get('/categories', async (_req, res) => {
  res.json({ items: await listCategories() });
});

referenceRouter.post('/categories', endpointRetired);
referenceRouter.patch('/categories/:id', endpointRetired);
