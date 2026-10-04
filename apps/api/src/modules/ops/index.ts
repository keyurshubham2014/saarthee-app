import { Router } from 'express';
import { config } from '../../config';
import { AppError } from '../../lib/errors';

/**
 * Ops hooks (V2 TASK-13 step 3, M-13-06). Mounted under /admin, so the admin JWT guard applies.
 * `POST /admin/__test-error` throws an unexpected error to exercise error alerting and the PII scrubber;
 * it exists only when DEPLOY_ENV=staging (404 everywhere else).
 */
export const opsAdminRouter = Router();

opsAdminRouter.post('/__test-error', () => {
  if (config.DEPLOY_ENV !== 'staging') throw new AppError('NOT_FOUND');
  throw new Error('Saarthee staging test error (M-13-06)');
});
