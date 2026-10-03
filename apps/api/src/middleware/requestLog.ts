import type { Request, RequestHandler } from 'express';
import { logger } from '../lib/logger';

const templates = new WeakMap<Request, string>();

/** Route template (e.g. /api/v1/admin/complaints/:id), never the raw URL. */
export function routeTemplate(req: Request): string {
  return templates.get(req) ?? '(unmatched)';
}

/**
 * Express resets req.baseUrl when an error leaves a router, so the template is captured at the
 * moment the router assigns req.route (baseUrl is correct then).
 */
function captureRouteTemplate(req: Request) {
  let route: unknown;
  Object.defineProperty(req, 'route', {
    configurable: true,
    enumerable: true,
    get: () => route,
    set: (value: { path?: unknown } | undefined) => {
      route = value;
      if (value && typeof value.path === 'string') templates.set(req, `${req.baseUrl}${value.path}`);
    },
  });
}

export const requestLog: RequestHandler = (req, res, next) => {
  const start = process.hrtime.bigint();
  captureRouteTemplate(req);
  res.on('finish', () => {
    const durationMs = Number((process.hrtime.bigint() - start) / 1_000_000n);
    logger.info(
      { requestId: req.id, method: req.method, route: routeTemplate(req), status: res.statusCode, durationMs },
      'request',
    );
  });
  next();
};
