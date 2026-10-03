import { Router } from 'express';
import { AppError } from '../../lib/errors';
import { databaseReachable } from './health.service';

export const publicRouter = Router();

publicRouter.get('/health', async (_req, res) => {
  if (!(await databaseReachable())) throw new AppError('SERVICE_UNAVAILABLE');
  res.json({ status: 'ok', db: 'ok' });
});
