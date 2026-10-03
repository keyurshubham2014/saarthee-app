import { Router } from 'express';
import { publicRouter } from './modules/public';
import { eventsRouter } from './modules/events';

export const apiRouter = Router();
apiRouter.use(publicRouter);
apiRouter.use(eventsRouter);
