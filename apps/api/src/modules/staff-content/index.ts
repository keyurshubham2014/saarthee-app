/**
 * Staff content APIs (V2 TASK-12 §5.3): services, initiatives, tips, link re-check, RSVP list and
 * attendance. Every write is role-guarded (requireUser + requireRole) and audited via staffContentAudit.
 * TASK-10's console hosts the matching staff screens.
 */
import { Router } from 'express';
import { staffInitiativesRouter } from './initiatives.routes';
import { staffServicesRouter } from './services.routes';
import { staffTipsRouter } from './tips.routes';

export const staffContentRouter = Router();
staffContentRouter.use(staffServicesRouter);
staffContentRouter.use(staffInitiativesRouter);
staffContentRouter.use(staffTipsRouter);
