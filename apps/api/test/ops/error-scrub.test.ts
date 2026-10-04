/** T-13-07 (V2 TASK-13 AC-8): error events keep the allow-list only; phone/JWT/coords/body/IP/headers are gone. */
import { beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';
import request from 'supertest';
import { scrubEvent, scrubText, type ReportEvent } from '../../src/lib/errors/scrub';
import { resetDb } from '../helpers/db';

// Before any import reads the config (it is loaded once per file).
vi.hoisted(() => {
  process.env.DEPLOY_ENV = 'staging';
  process.env.STAFF_WEB_ORIGINS = ''; // a developer's local http origin is invalid outside local
});

const PHONE = '+919876543210';
const JWT = 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjMifQ.c2lnbmF0dXJlLXZhbHVl';
const COORDS = '23.022505,72.571365';

function dirtyEvent(): ReportEvent {
  return {
    event_id: 'e1',
    level: 'error',
    environment: 'staging',
    release: 'abc123',
    exception: {
      values: [
        {
          type: 'Error',
          value: `failed for ${PHONE} at ${COORDS} token ${JWT}`,
          stacktrace: { frames: [{ filename: 'dist/src/app.js', function: 'h', lineno: 3, colno: 7, vars: { phone: PHONE } } as never] },
        },
      ],
    },
    tags: { route: '/issues/:id?lat=23.02&lng=72.57', method: 'POST', status: 500, requestId: 'req-1', phone: PHONE },
    request: {
      method: 'POST',
      url: `https://api.example.in/api/v1/issues/1?lat=23.0225&lng=72.5713`,
      query_string: `lat=23.0225&lng=72.5713`,
      data: { phone: PHONE, description: 'pothole' },
      cookies: { session: 'abc' },
      headers: { 'user-agent': 'Saarthee/2.0 Android', authorization: `Bearer ${JWT}`, 'x-forwarded-for': '203.0.113.9' },
      env: { REMOTE_ADDR: '203.0.113.9' },
    },
    user: { ip_address: '203.0.113.9', id: 'u1' },
    extra: { body: { phone: PHONE } },
    contexts: { trace: { data: { phone: PHONE } } },
    breadcrumbs: [{ category: 'http', message: 'GET /x?phone=9876543210', data: { url: '/api/v1/x?lat=23.02', method: 'GET' } }],
  };
}

describe('scrubEvent', () => {
  it('drops body, query, cookies, headers, user, IP, extra and contexts; scrubs kept strings', () => {
    const out = scrubEvent(dirtyEvent());
    const json = JSON.stringify(out);
    for (const secret of [PHONE, '9876543210', JWT, COORDS, '23.0225', '203.0.113.9', 'pothole', 'authorization', 'cookies', 'session']) {
      expect(json).not.toContain(secret);
    }
    expect(out.user).toBeUndefined();
    expect(out.extra).toBeUndefined();
    expect(out.contexts).toBeUndefined();
  });

  it('keeps exception type/message/stack, route template, method, status, request id, release and environment', () => {
    const out = scrubEvent(dirtyEvent());
    expect(out.exception?.values?.[0]?.type).toBe('Error');
    expect(out.exception?.values?.[0]?.value).toBe('failed for [scrubbed] at [scrubbed] token [scrubbed]');
    expect(out.exception?.values?.[0]?.stacktrace?.frames?.[0]).toEqual({
      filename: 'dist/src/app.js', function: 'h', lineno: 3, colno: 7, in_app: undefined, module: undefined,
    });
    expect(out.tags).toEqual({ route: '/issues/:id', method: 'POST', status: '500', requestId: 'req-1' });
    expect(out.request).toEqual({ method: 'POST', headers: { 'user-agent': 'Saarthee/2.0 Android' } });
    expect(out.release).toBe('abc123');
    expect(out.environment).toBe('staging');
    expect(out.breadcrumbs?.[0]).toMatchObject({ category: 'http', message: 'GET /x', data: { url: '/api/v1/x' } });
  });

  it('scrubText covers bare 10-digit mobiles and lat/lng parameters', () => {
    expect(scrubText('call 9876543210 now')).toBe('call [scrubbed] now');
    expect(scrubText('lat=23.02 lng: 72.5')).toBe('[scrubbed] [scrubbed]');
  });
});

describe('POST /admin/__test-error (DEPLOY_ENV=staging)', () => {
  let app: import('express').Express;
  let auth: Record<string, string>;
  beforeAll(async () => {
    app = (await import('../../src/app')).createApp();
  });
  beforeEach(async () => {
    await resetDb();
    auth = (await (await import('../helpers/auth')).createAdmin()).auth;
  });

  it('returns 500 INTERNAL_ERROR with a request id and no internal detail', async () => {
    const res = await request(app).post('/api/v1/admin/__test-error?lat=23.02').set(auth).send({ phone: PHONE });
    expect(res.status).toBe(500);
    expect(res.body.error.code).toBe('INTERNAL_ERROR');
    expect(res.body.error.requestId).toBeTruthy();
    expect(JSON.stringify(res.body)).not.toContain('M-13-06');
  });
});
