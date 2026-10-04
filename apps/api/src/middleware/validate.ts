import type { RequestHandler } from 'express';
import type { z } from 'zod';
import { AppError } from '../lib/errors';
import { parseAcceptLanguage } from '../lib/lang';

interface Schemas {
  body?: z.ZodType;
  query?: z.ZodType;
  params?: z.ZodType;
}

/**
 * Validates and replaces req.body / req.query / req.params with the parsed value.
 * Zod objects strip unknown keys by default. Parsed query/params are exposed via res.locals
 * because Express 5 makes req.query a getter.
 * Raw SQL must only use Prisma's tagged-template $queryRaw (parameterized), never string building.
 * Query schemas with a `lang` key take it from Accept-Language when `?lang=` is absent (`Vary` is set).
 */
export function validate(schemas: Schemas): RequestHandler {
  return (req, res, next) => {
    const details: { field: string; issue: string }[] = [];
    const run = (key: keyof Schemas, value: unknown) => {
      const schema = schemas[key];
      if (!schema) return undefined;
      const r = schema.safeParse(value ?? {});
      if (!r.success) {
        for (const i of r.error.issues) details.push({ field: i.path.join('.') || key, issue: i.message });
        return undefined;
      }
      return r.data;
    };
    const body = run('body', req.body);
    const query = run('query', withHeaderLang(schemas.query, req.query, req.header('accept-language'), () => res.vary('Accept-Language')));
    const params = run('params', req.params);
    if (details.length > 0) return next(new AppError('VALIDATION_FAILED', { details }));
    if (schemas.body) req.body = body;
    res.locals.query = query;
    res.locals.params = params;
    next();
  };
}

/** Adds `lang` from Accept-Language to a raw query whose schema has a `lang` key and that has no `lang` yet. */
function withHeaderLang(schema: z.ZodType | undefined, query: unknown, header: string | undefined, vary: () => void): unknown {
  const shape = (schema as { shape?: Record<string, unknown> } | undefined)?.shape;
  if (!shape || !('lang' in shape)) return query;
  vary();
  const q = (query ?? {}) as Record<string, unknown>;
  if (q.lang !== undefined) return query;
  const lang = parseAcceptLanguage(header);
  return lang ? { ...q, lang } : query;
}
