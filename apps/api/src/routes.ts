import { Router } from 'express';
import { publicRouter } from './modules/public';
import { eventsRouter } from './modules/events';
import { photosRouter } from './modules/photos';
import { reportsRouter } from './modules/reports';
import { adminLoginRouter } from './modules/admin-auth';
import { verifyRouter } from './modules/verify';
import { adminRouter } from './modules/admin';

export const apiRouter = Router();
apiRouter.use(publicRouter);
apiRouter.use(eventsRouter);
apiRouter.use(photosRouter);
apiRouter.use(reportsRouter);
apiRouter.use(verifyRouter);
apiRouter.use(adminLoginRouter);
apiRouter.use('/admin', adminRouter);
