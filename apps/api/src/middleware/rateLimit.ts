import type { Request } from 'express';
import { rateLimit as erl, ipKeyGenerator } from 'express-rate-limit';
import { AppError, errorBody } from '../lib/errors';
import { logger } from '../lib/logger';
import { routeTemplate } from './requestLog';

interface Options {
  windowMs: number;
  max: number;
  keyGenerator?: (req: Request) => string;
  /** Count only failed responses (status >= 400), e.g. bad logins. */
  skipSuccessfulRequests?: boolean;
  /** Extra context for the warn log line (must not contain personal data). */
  logContext?: (req: Request) => Record<string, string>;
}

/** In-memory limiter; 429 RATE_LIMITED in the standard shape + Retry-After. */
export function rateLimit({ windowMs, max, keyGenerator, skipSuccessfulRequests, logContext }: Options) {
  return erl({
    windowMs,
    limit: max,
    standardHeaders: 'draft-7',
    legacyHeaders: false,
    skipSuccessfulRequests: skipSuccessfulRequests ?? false,
    keyGenerator: keyGenerator ?? ((req) => ipKeyGenerator(req.ip ?? 'unknown')),
    handler: (req, res) => {
      logger.warn({ requestId: req.id, route: routeTemplate(req), ...(logContext ? logContext(req) : {}) }, 'rate limited');
      res.setHeader('Retry-After', String(Math.ceil(windowMs / 1000)));
      res.status(429).json(errorBody(new AppError('RATE_LIMITED'), req.id));
    },
  });
}

export const ipKey = (req: Request) => ipKeyGenerator(req.ip ?? 'unknown');
