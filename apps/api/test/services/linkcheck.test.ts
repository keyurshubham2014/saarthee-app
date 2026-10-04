// T-12-04 (checkUrl, fake fetch) and T-12-05 (link-check run updates rows; staff ?linkOk=false), AC-4.
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { prisma } from '../../src/lib/db';
import { checkUrl, type FetchLike } from '../../src/lib/linkcheck';
import { checkAllServiceLinks, summaryTable } from '../../src/modules/services/link-check';
import { setLinkCheckOptions } from '../../src/modules/staff-content/services.routes';
import { api } from '../helpers/app';
import { resetDb } from '../helpers/db';
import { makeService, roleUser } from './helpers';

type Behaviour = (method: string) => number | { status: number; location: string } | Error;

function fakeFetch(routes: Record<string, Behaviour>) {
  const calls: { url: string; method: string; ua: string }[] = [];
  const fetch: FetchLike = async (url, init) => {
    calls.push({ url, method: init.method, ua: init.headers['User-Agent']! });
    const b = routes[url];
    if (!b) throw Object.assign(new TypeError('fetch failed'), { cause: { code: 'ENOTFOUND' } });
    const r = b(init.method);
    if (r instanceof Error) throw r;
    const status = typeof r === 'number' ? r : r.status;
    const location = typeof r === 'number' ? null : r.location;
    return { status, headers: { get: (n: string) => (n.toLowerCase() === 'location' ? location : null) }, body: { cancel: async () => undefined } };
  };
  return { fetch, calls };
}

const timeoutErr = () => Object.assign(new Error('The operation was aborted due to timeout'), { name: 'TimeoutError' });
const noSleep = async () => undefined;

describe('T-12-04 checkUrl', () => {
  it('handles 200, 404, timeout, HEAD 405 → GET 200, > 5 redirects, TLS, DNS and a retried network error', async () => {
    let flaky = 0;
    const { fetch, calls } = fakeFetch({
      'https://ok.test/': () => 200,
      'https://gone.test/': () => 404,
      'https://slow.test/': () => timeoutErr(),
      'https://headless.test/': (m) => (m === 'HEAD' ? 405 : 200),
      'https://loop.test/': () => ({ status: 302, location: 'https://loop.test/' }),
      'https://hop.test/': () => ({ status: 301, location: '/final' }),
      'https://hop.test/final': () => 200,
      'https://tls.test/': () => Object.assign(new TypeError('fetch failed'), { cause: { code: 'CERT_HAS_EXPIRED' } }),
      'https://flaky.test/': () => (flaky++ === 0 ? Object.assign(new TypeError('fetch failed'), { cause: { code: 'ECONNRESET' } }) : 200),
    });
    const o = { fetch, userAgent: 'SaartheeLinkCheck/1.0 (+mailto:test@example.test)', sleep: noSleep };
    expect(await checkUrl('https://ok.test/', o)).toEqual({ ok: true, statusCode: 200, error: null });
    expect(await checkUrl('https://gone.test/', o)).toEqual({ ok: false, statusCode: 404, error: 'http_404' });
    expect(await checkUrl('https://slow.test/', o)).toEqual({ ok: false, statusCode: null, error: 'timeout' });
    expect(await checkUrl('https://headless.test/', o)).toEqual({ ok: true, statusCode: 200, error: null });
    expect(await checkUrl('https://loop.test/', o)).toEqual({ ok: false, statusCode: null, error: 'too_many_redirects' });
    expect(calls.filter((c) => c.url === 'https://loop.test/')).toHaveLength(6);
    expect(await checkUrl('https://hop.test/', o)).toEqual({ ok: true, statusCode: 200, error: null });
    expect(await checkUrl('https://tls.test/', o)).toEqual({ ok: false, statusCode: null, error: 'tls' });
    expect(await checkUrl('https://nowhere.test/', o)).toEqual({ ok: false, statusCode: null, error: 'dns' });
    expect(await checkUrl('https://flaky.test/', o)).toEqual({ ok: true, statusCode: 200, error: null });
    expect(calls.filter((c) => c.url === 'https://headless.test/').map((c) => c.method)).toEqual(['HEAD', 'GET']);
    expect(calls.every((c) => c.ua.startsWith('SaartheeLinkCheck/1.0'))).toBe(true);
  });
});

describe('T-12-05 services:check-links run', () => {
  beforeEach(resetDb);
  afterEach(() => setLinkCheckOptions({}));

  it('stores link_ok/status/error for every active service, prints a summary and never throws for broken links', async () => {
    const { fetch } = fakeFetch({
      'https://a.test/ok': () => 200,
      'https://a.test/gone': () => 404,
      'https://b.test/slow': () => timeoutErr(),
      'https://c.test/head': (m) => (m === 'HEAD' ? 405 : 200),
    });
    await makeService({ slug: 'link-ok', url: 'https://a.test/ok' });
    await makeService({ slug: 'link-gone', url: 'https://a.test/gone' });
    await makeService({ slug: 'link-slow', url: 'https://b.test/slow' });
    await makeService({ slug: 'link-head', url: 'https://c.test/head' });
    await makeService({ slug: 'link-inactive', url: 'https://a.test/gone', isActive: false });

    const rows = await checkAllServiceLinks({ fetch, sleep: noSleep, perHostGapMs: 0 });
    expect(rows.map((r) => [r.slug, r.ok, r.error])).toEqual([
      ['link-gone', false, 'http_404'],
      ['link-head', true, null],
      ['link-ok', true, null],
      ['link-slow', false, 'timeout'],
    ]);
    const db = await prisma.service.findMany({ orderBy: { slug: 'asc' } });
    const by = Object.fromEntries(db.map((s) => [s.slug, s]));
    expect(by['link-ok']).toMatchObject({ linkOk: true, linkStatusCode: 200, linkError: null });
    expect(by['link-gone']).toMatchObject({ linkOk: false, linkStatusCode: 404, linkError: 'http_404' });
    expect(by['link-slow']).toMatchObject({ linkOk: false, linkStatusCode: null, linkError: 'timeout' });
    expect(by['link-head']).toMatchObject({ linkOk: true, linkStatusCode: 200 });
    expect(by['link-inactive']!.lastCheckedAt).toBeNull();
    for (const slug of ['link-ok', 'link-gone', 'link-slow', 'link-head']) expect(by[slug]!.lastCheckedAt).toBeInstanceOf(Date);
    expect(summaryTable(rows)).toContain('4 checked, 2 ok, 2 broken');

    const mod = await roleUser('moderator');
    const broken = await api().get('/api/v1/staff/services').query({ linkOk: 'false' }).set(mod.auth);
    expect(broken.status).toBe(200);
    expect(broken.body.items.map((s: { slug: string }) => s.slug).sort()).toEqual(['link-gone', 'link-slow']);
    const pub = await api().get('/api/v1/services');
    expect(pub.body.items.find((s: { slug: string }) => s.slug === 'link-gone').linkOk).toBe(false);
  });

  it('waits at least the per-host gap between two requests to the same host', async () => {
    const { fetch } = fakeFetch({ 'https://a.test/1': () => 200, 'https://a.test/2': () => 200 });
    await makeService({ slug: 'gap-1', url: 'https://a.test/1' });
    await makeService({ slug: 'gap-2', url: 'https://a.test/2' });
    const waits: number[] = [];
    await checkAllServiceLinks({ fetch, perHostGapMs: 1000, sleep: async (ms) => void waits.push(ms) });
    expect(waits).toHaveLength(1);
    expect(waits[0]).toBeGreaterThan(900);
  });
});
