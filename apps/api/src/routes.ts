import { Router } from 'express';
import { publicRouter } from './modules/public';
import { eventsRouter } from './modules/events';
import { photosRouter } from './modules/photos';
import { reportsRouter } from './modules/reports';
import { adminLoginRouter } from './modules/admin-auth';
import { verifyRouter } from './modules/verify';
import { adminRouter } from './modules/admin';
import { geoRouter } from './modules/geo';
import { authRouter } from './modules/auth';
import { meRouter } from './modules/me';
import { devicesRouter } from './modules/devices';
import { representativesRouter } from './modules/representatives';
import { settingsRouter } from './modules/settings';
import { staffRepresentativesRouter } from './modules/staff-representatives';
import { categoriesRouter } from './modules/categories';
import { issuesRouter } from './modules/issues';
import { alertsRouter } from './modules/alerts';
import { staffAlertsRouter } from './modules/staff-alerts';
import { servicesRouter } from './modules/services';
import { initiativesRouter } from './modules/initiatives';
import { staffContentRouter } from './modules/staff-content';
import { lifecycleRouter } from './modules/lifecycle';
import { escalationRouter } from './modules/escalation';

export const apiRouter = Router();
apiRouter.use(publicRouter);
apiRouter.use(eventsRouter);
apiRouter.use(photosRouter);
apiRouter.use(reportsRouter);
apiRouter.use(verifyRouter);
apiRouter.use(adminLoginRouter);
apiRouter.use('/admin', adminRouter);
apiRouter.use(geoRouter);
// TASK-04: citizen accounts, privacy and device registration.
apiRouter.use(authRouter);
apiRouter.use(meRouter);
apiRouter.use(devicesRouter);
// TASK-09: representatives, relay, scorecard, public settings/election mode, staff roster.
apiRouter.use(representativesRouter);
apiRouter.use(settingsRouter);
apiRouter.use(staffRepresentativesRouter);
// TASK-05: v2 categories (with AMC problem types) and standalone issue reporting.
apiRouter.use(categoriesRouter);
apiRouter.use(issuesRouter);
// TASK-08: civic alerts, subscriptions, notification inbox; staff alert composer and approval.
apiRouter.use(alertsRouter);
apiRouter.use(staffAlertsRouter);
// TASK-12: AMC services directory, civic initiatives and their staff APIs.
apiRouter.use(servicesRouter);
apiRouter.use(initiativesRouter);
apiRouter.use(staffContentRouter);
// TASK-06: issue lifecycle (status, verifications, events, AMC closed it) and escalation messages.
apiRouter.use(lifecycleRouter);
apiRouter.use(escalationRouter);
