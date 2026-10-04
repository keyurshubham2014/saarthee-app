/**
 * Hardened GET for feed polling (§5.3 SACHET): HTTPS only, 10 s timeout, ≤ 2 MB, conditional requests
 * (ETag / If-Modified-Since), at most 3 same-host redirects, fixed User-Agent. Never logs bodies.
 */
export const FEED_TIMEOUT_MS = 10_000;
export const FEED_MAX_BYTES = 2 * 1024 * 1024;
const USER_AGENT = 'Saarthee/2 (+https://saarthee.app/contact)';

export type FetchText = (url: string) => Promise<{ status: 'ok'; body: string } | { status: 'not_modified' }>;

const validators = new Map<string, { etag?: string; lastModified?: string }>();

async function readCapped(res: Response): Promise<string> {
  const declared = Number(res.headers.get('content-length') ?? '0');
  if (declared > FEED_MAX_BYTES) throw new Error('feed too large');
  if (!res.body) return '';
  const reader = res.body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > FEED_MAX_BYTES) {
      await reader.cancel();
      throw new Error('feed too large');
    }
    chunks.push(value);
  }
  return Buffer.concat(chunks).toString('utf8');
}

export const httpFetchText: FetchText = async (url) => {
  let current = new URL(url);
  if (current.protocol !== 'https:') throw new Error('feed URL must be https');
  const host = current.host;
  for (let hop = 0; hop < 4; hop++) {
    const v = validators.get(current.href) ?? {};
    const res = await fetch(current, {
      redirect: 'manual',
      signal: AbortSignal.timeout(FEED_TIMEOUT_MS),
      headers: {
        'User-Agent': USER_AGENT,
        Accept: 'application/xml, text/xml;q=0.9',
        ...(v.etag ? { 'If-None-Match': v.etag } : {}),
        ...(v.lastModified ? { 'If-Modified-Since': v.lastModified } : {}),
      },
    });
    if (res.status === 304) return { status: 'not_modified' };
    if (res.status >= 300 && res.status < 400) {
      const next = new URL(res.headers.get('location') ?? '', current);
      if (next.protocol !== 'https:' || next.host !== host) throw new Error('cross-host redirect refused');
      current = next;
      continue;
    }
    if (!res.ok) throw new Error(`feed HTTP ${res.status}`);
    const body = await readCapped(res);
    validators.set(current.href, { etag: res.headers.get('etag') ?? undefined, lastModified: res.headers.get('last-modified') ?? undefined });
    return { status: 'ok', body };
  }
  throw new Error('too many redirects');
};
