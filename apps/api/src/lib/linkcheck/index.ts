/**
 * Polite link checker (V2 TASK-12 §5.3, REQ-F-058). `checkUrl` is pure apart from the injected fetch:
 * HEAD with our User-Agent, ≤ 5 redirects followed by hand, GET fallback on 403/405/501 (body discarded
 * after the headers), one retry after `retryDelayMs` on a network error. Never stores response bodies.
 */
export type FetchLike = (url: string, init: { method: string; headers: Record<string, string>; redirect: 'manual'; signal: AbortSignal }) => Promise<{
  status: number;
  headers: { get(name: string): string | null };
  body?: { cancel(): Promise<void> } | null;
}>;

export interface CheckOptions {
  fetch?: FetchLike;
  userAgent?: string;
  timeoutMs?: number;
  maxRedirects?: number;
  retryDelayMs?: number;
  sleep?: (ms: number) => Promise<void>;
}

export interface CheckResult {
  ok: boolean;
  statusCode: number | null;
  /** `timeout`, `dns`, `tls`, `network`, `too_many_redirects`, `bad_redirect` or `http_<code>`; null when ok. */
  error: string | null;
}

const GET_FALLBACK = new Set([403, 405, 501]);
const defaultSleep = (ms: number) => new Promise<void>((r) => setTimeout(r, ms));

class LinkError extends Error {
  constructor(readonly code: string) {
    super(code);
  }
}

/** Maps a thrown fetch error to a short code (no messages or bodies kept). */
export function errorCode(err: unknown): string {
  if (err instanceof LinkError) return err.code;
  const e = err as { name?: string; code?: string; cause?: { code?: string; name?: string } };
  if (e?.name === 'TimeoutError' || e?.name === 'AbortError' || e?.cause?.name === 'TimeoutError') return 'timeout';
  const code = e?.cause?.code ?? e?.code ?? '';
  if (code === 'ENOTFOUND' || code === 'EAI_AGAIN') return 'dns';
  if (/CERT|TLS|SSL|SELF_SIGNED|UNABLE_TO_VERIFY/i.test(code)) return 'tls';
  return 'network';
}

async function request(url: string, method: 'HEAD' | 'GET', o: Required<Omit<CheckOptions, 'sleep' | 'retryDelayMs'>>) {
  let current = url;
  for (let hop = 0; ; hop += 1) {
    const res = await o.fetch(current, {
      method,
      headers: { 'User-Agent': o.userAgent, Accept: 'text/html,*/*;q=0.8' },
      redirect: 'manual',
      signal: AbortSignal.timeout(o.timeoutMs),
    });
    if (method === 'GET') await res.body?.cancel().catch(() => undefined);
    if (res.status < 300 || res.status >= 400) return res.status;
    const location = res.headers.get('location');
    if (!location) return res.status;
    if (hop >= o.maxRedirects) throw new LinkError('too_many_redirects');
    try {
      current = new URL(location, current).toString();
    } catch {
      throw new LinkError('bad_redirect');
    }
  }
}

async function attempt(url: string, o: Required<Omit<CheckOptions, 'sleep' | 'retryDelayMs'>>): Promise<number> {
  const status = await request(url, 'HEAD', o);
  return GET_FALLBACK.has(status) ? request(url, 'GET', o) : status;
}

export async function checkUrl(url: string, opts: CheckOptions = {}): Promise<CheckResult> {
  const o = {
    fetch: opts.fetch ?? (globalThis.fetch as unknown as FetchLike),
    userAgent: opts.userAgent ?? process.env.LINK_CHECK_USER_AGENT ?? 'SaartheeLinkCheck/1.0',
    timeoutMs: opts.timeoutMs ?? Number(process.env.LINK_CHECK_TIMEOUT_MS ?? 10_000),
    maxRedirects: opts.maxRedirects ?? 5,
  };
  const sleep = opts.sleep ?? defaultSleep;
  for (let tryNo = 0; ; tryNo += 1) {
    try {
      const status = await attempt(url, o);
      return status < 400 ? { ok: true, statusCode: status, error: null } : { ok: false, statusCode: status, error: `http_${status}` };
    } catch (err) {
      const code = errorCode(err);
      if (code !== 'network' || tryNo >= 1) return { ok: false, statusCode: null, error: code };
      await sleep(opts.retryDelayMs ?? 30_000);
    }
  }
}
