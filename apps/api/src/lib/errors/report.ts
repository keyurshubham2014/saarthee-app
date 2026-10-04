/**
 * Error reporting (V2 TASK-13 §5.3, REQ-O-007). No-op unless SENTRY_DSN is set. Sentry is loaded lazily,
 * with default integrations off (no request/HTTP instrumentation, no IP, no breadcrumbs from HTTP), and
 * every event passes through the allow-list scrubber before it leaves the process.
 */
import type * as SentryNS from '@sentry/node';
import { config } from '../../config';
import { scrubEvent, type ReportEvent } from './scrub';

let sentry: typeof SentryNS | undefined;

export function initErrorReporting(): boolean {
  if (!config.SENTRY_DSN || sentry) return Boolean(sentry);
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const S = require('@sentry/node') as typeof SentryNS;
  S.init({
    dsn: config.SENTRY_DSN,
    environment: config.DEPLOY_ENV,
    release: process.env.APP_RELEASE,
    // Sentry v11 replaced sendDefaultPii with dataCollection: collect nothing about users or requests.
    dataCollection: {
      userInfo: false,
      cookies: false,
      httpHeaders: { request: { allow: ['user-agent'] }, response: false },
      httpBodies: [],
      urlQueryParams: false,
      databaseQueryData: false,
      stackFrameVariables: false,
      frameContextLines: 0,
    },
    defaultIntegrations: false,
    integrations: [],
    tracesSampleRate: config.SENTRY_TRACES_SAMPLE_RATE,
    maxBreadcrumbs: 0,
    beforeSend: (event) => scrubEvent(event as unknown as ReportEvent) as unknown as typeof event,
    beforeBreadcrumb: () => null,
  });
  sentry = S;
  return true;
}

export interface ErrorContext {
  route: string;
  method: string;
  status: number;
  requestId: string;
}

/** Sends an unexpected (5xx) error with route template, method, status and request id only. */
export function reportError(err: unknown, ctx: ErrorContext): void {
  if (!sentry) return;
  const S = sentry;
  S.withScope((scope) => {
    scope.setTag('route', ctx.route);
    scope.setTag('method', ctx.method);
    scope.setTag('status', String(ctx.status));
    scope.setTag('requestId', ctx.requestId);
    S.captureException(err);
  });
}

/** Flushes pending events (shutdown). */
export async function flushErrorReporting(timeoutMs = 2000): Promise<void> {
  if (sentry) await sentry.flush(timeoutMs);
}
