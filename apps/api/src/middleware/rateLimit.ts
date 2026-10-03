import type { Request } from 'express';
import { rateLimit as erl, ipKeyGenerator } from 'express-rate-limit';
import { AppError, errorBody } from '../lib/errors';
import { logger } from '../lib/logger';
import { routeTemplate } from './requestLog';

interface Options {
  windowMs: number;
  max: number;
  keyGenerator?: (req: Request) => string;
}

/** In-memory limiter; 429 RATE_LIMITED in the standard shape + Retry-After. */
export function rateLimit({ windowMs, max, keyGenerator }: Options) {
  return erl({
    windowMs,
    limit: max,
    standardHeaders: 'draft-7',
    legacyHeaders: false,
    keyGenerator: keyGenerator ?? ((req) => ipKeyGenerator(req.ip ?? 'unknown')),
    handler: (req, res) => {
      logger.warn({ requestId: req.id, route: routeTemplate(req) }, 'rate limited');
      res.setHeader('Retry-After', String(Math.ceil(windowMs / 1000)));
      res.status(429).json(errorBody(new AppError('RATE_LIMITED'), req.id));
    },
  });
}

export const ipKey = (req: Request) => ipKeyGenerator(req.ip ?? 'unknown');
