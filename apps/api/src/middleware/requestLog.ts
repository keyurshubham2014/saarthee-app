import type { Request, RequestHandler } from 'express';
import { logger } from '../lib/logger';

/** Route template (e.g. /api/v1/admin/complaints/:id), never the raw URL. */
export function routeTemplate(req: Request): string {
  const path = req.route?.path as string | undefined;
  return path ? `${req.baseUrl}${path}` : '(unmatched)';
}

export const requestLog: RequestHandler = (req, res, next) => {
  const start = process.hrtime.bigint();
  res.on('finish', () => {
    const durationMs = Number((process.hrtime.bigint() - start) / 1_000_000n);
    logger.info(
      { requestId: req.id, method: req.method, route: routeTemplate(req), status: res.statusCode, durationMs },
      'request',
    );
  });
  next();
};
