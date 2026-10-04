/**
 * PII scrubber for error reports (V2 TASK-13 §5.3, T-13-07). Allow-list: a NEW event is built from the
 * fields below; everything else (request body, query string, cookies, headers other than user-agent,
 * user, IP, extra, contexts) is dropped. Every kept string is passed through scrubText.
 */

// Indian mobile numbers with or without +91, JWTs, and coordinate pairs / lat-lng parameters.
const PATTERNS: RegExp[] = [
  /\+?91[6-9]\d{9}/g,
  /\b[6-9]\d{9}\b/g,
  /eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]*/g,
  /-?\d{1,3}\.\d{3,}\s*,\s*-?\d{1,3}\.\d{3,}/g,
  /\b(lat|lng|lon|latitude|longitude)\s*[=:]\s*-?\d{1,3}(\.\d+)?/gi,
];

export function scrubText(s: string): string {
  return PATTERNS.reduce((acc, re) => acc.replace(re, '[scrubbed]'), s);
}

/** Strips the query string and fragment from a URL or path. */
export function stripQuery(url: string): string {
  return url.replace(/[?#].*$/, '');
}

interface Frame {
  filename?: string;
  function?: string;
  lineno?: number;
  colno?: number;
  in_app?: boolean;
  module?: string;
}
interface ExceptionValue {
  type?: string;
  value?: string;
  stacktrace?: { frames?: Frame[] };
  mechanism?: unknown;
}
export interface ReportEvent {
  event_id?: string;
  timestamp?: number;
  platform?: string;
  level?: string;
  release?: string;
  environment?: string;
  message?: string;
  exception?: { values?: ExceptionValue[] };
  tags?: Record<string, unknown>;
  request?: { method?: string; url?: string; headers?: Record<string, string>; [k: string]: unknown };
  breadcrumbs?: { category?: string; message?: string; level?: string; timestamp?: number; data?: Record<string, unknown> }[];
  [k: string]: unknown;
}

const TAGS = ['route', 'method', 'status', 'requestId'] as const;

function str(v: unknown): string | undefined {
  return typeof v === 'string' ? scrubText(v) : typeof v === 'number' ? String(v) : undefined;
}

export function scrubEvent<T extends ReportEvent>(event: T): T {
  const out: ReportEvent = {
    event_id: event.event_id,
    timestamp: event.timestamp,
    platform: event.platform,
    level: event.level,
    release: event.release,
    environment: event.environment,
  };
  if (event.message) out.message = scrubText(event.message);
  if (event.exception?.values) {
    out.exception = {
      values: event.exception.values.map((v) => ({
        type: v.type,
        value: v.value === undefined ? undefined : scrubText(v.value),
        mechanism: v.mechanism,
        stacktrace: v.stacktrace?.frames
          ? {
              frames: v.stacktrace.frames.map((f) => ({
                filename: f.filename,
                function: f.function,
                lineno: f.lineno,
                colno: f.colno,
                in_app: f.in_app,
                module: f.module,
              })),
            }
          : undefined,
      })),
    };
  }
  const tags: Record<string, string> = {};
  for (const k of TAGS) {
    const v = str(event.tags?.[k]);
    if (v !== undefined) tags[k] = k === 'route' ? stripQuery(v) : v;
  }
  out.tags = tags;
  if (event.request) {
    const ua = event.request.headers?.['user-agent'] ?? event.request.headers?.['User-Agent'];
    out.request = {
      method: event.request.method,
      ...(ua ? { headers: { 'user-agent': scrubText(ua) } } : {}),
    };
  }
  if (event.breadcrumbs) {
    out.breadcrumbs = event.breadcrumbs.map((b) => {
      const url = typeof b.data?.url === 'string' ? stripQuery(scrubText(b.data.url)) : undefined;
      return {
        category: b.category,
        level: b.level,
        timestamp: b.timestamp,
        message: b.message === undefined ? undefined : scrubText(stripQuery(b.message)),
        ...(url ? { data: { url } } : {}),
      };
    });
  }
  return out as T;
}
