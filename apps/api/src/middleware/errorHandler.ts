import type { ErrorRequestHandler, RequestHandler } from 'express';
import { AppError, errorBody } from '../lib/errors';
import { logger } from '../lib/logger';
import { routeTemplate } from './requestLog';

export const notFound: RequestHandler = (req, res) => {
  res.status(404).json(errorBody(new AppError('NOT_FOUND'), req.id));
};

export const errorHandler: ErrorRequestHandler = (err, req, res, _next) => {
  let appErr: AppError;
  if (err instanceof AppError) {
    appErr = err;
  } else if (err?.type === 'entity.too.large') {
    appErr = new AppError('VALIDATION_FAILED', { status: 413, message: 'Request body too large.' });
  } else if (err?.type === 'entity.parse.failed') {
    appErr = new AppError('VALIDATION_FAILED', { message: 'Request body is not valid JSON.' });
  } else {
    // Stack goes to logs only, never to the client.
    logger.error({ requestId: req.id, route: routeTemplate(req), err }, 'unhandled error');
    appErr = new AppError('INTERNAL_ERROR');
  }
  if (appErr.status >= 500 && err instanceof AppError) {
    logger.error({ requestId: req.id, route: routeTemplate(req), code: appErr.code }, 'server error');
  }
  if (appErr.code === 'RATE_LIMITED' && !res.getHeader('Retry-After')) res.setHeader('Retry-After', '60');
  res.status(appErr.status).json(errorBody(appErr, req.id));
};
