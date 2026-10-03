import { Router } from 'express';
import { publicRouter } from './modules/public';

export const apiRouter = Router();
apiRouter.use(publicRouter);
