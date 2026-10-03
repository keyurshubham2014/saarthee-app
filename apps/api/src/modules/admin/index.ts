import { Router } from 'express';
import { rateLimit } from '../../middleware/rateLimit';
import { requireAdmin } from '../../middleware/requireAdmin';
import { adminAuthRouter } from '../admin-auth';
import { adminComplaintsRouter } from '../admin-complaints';
import { ratesRouter } from '../rates';

/**
 * Every route on this router is behind the JWT guard and the per-admin limiter (03 §10: 300/admin/min).
 * Admin feature modules attach their routers here.
 */
export const adminRouter = Router();
adminRouter.use(requireAdmin);
adminRouter.use(rateLimit({ windowMs: 60_000, max: 300, keyGenerator: (req) => `admin:${req.admin?.id ?? 'none'}` }));
adminRouter.use(adminAuthRouter);
adminRouter.use(adminComplaintsRouter);
adminRouter.use(ratesRouter);
