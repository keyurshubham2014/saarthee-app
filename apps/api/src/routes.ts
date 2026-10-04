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
