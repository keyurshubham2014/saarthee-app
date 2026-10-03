import type { RequestHandler } from 'express';
import { AppError } from '../lib/errors';

/**
 * v1 citizen/pilot writes retired by v2 (Spec D11, V2 TASK-01 §5.3): 410 ENDPOINT_RETIRED.
 * The v1 tables they wrote are read-only history (database triggers).
 */
export const endpointRetired: RequestHandler = (_req, _res, next) => {
  next(new AppError('ENDPOINT_RETIRED'));
};
