import { Router } from 'express';
import { publicRouter } from './modules/public';
import { eventsRouter } from './modules/events';
import { photosRouter } from './modules/photos';
import { reportsRouter } from './modules/reports';

export const apiRouter = Router();
apiRouter.use(publicRouter);
apiRouter.use(eventsRouter);
apiRouter.use(photosRouter);
apiRouter.use(reportsRouter);
