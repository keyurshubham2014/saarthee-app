/**
 * T-13-08 (V2 TASK-13 AC-3, AC-5): production headers and client IP behind Caddy/Cloudflare.
 * The config is read once per test file, so this file sets APP_ENV/TRUST_PROXY before importing the app.
 */
import request from 'supertest';
import { beforeAll, beforeEach, describe, expect, it } from 'vitest';

let app: import('express').Express;
let reset: () => Promise<void>;

beforeAll(async () => {
  process.env.APP_ENV = 'production';
  process.env.TRUST_PROXY = 'true';
  process.env.DEPLOY_ENV = 'pilot';
  // TASK-04 production rules: real Firebase verification (never called in this file).
  process.env.FIREBASE_AUTH_MODE = 'google';
  process.env.GOOGLE_APPLICATION_CREDENTIALS = '/run/secrets/firebase-sa.json';
  process.env.PUSH_DRIVER = 'log';
  app = (await import('../../src/app')).createApp();
  reset = (await import('../../src/middleware/rateLimit')).resetRateLimitStores;
});

beforeEach(async () => {
  await reset();
});

const health = (ip: string) => request(app).get('/api/v1/health').set('X-Forwarded-For', ip);

describe('production proxy behaviour', () => {
  it('sends HSTS (180 days, includeSubDomains) when APP_ENV=production', async () => {
    const res = await health('203.0.113.10');
    expect(res.status).toBe(200);
    expect(res.headers['strict-transport-security']).toBe('max-age=15552000; includeSubDomains');
  });

  it('keys the rate limit on X-Forwarded-For: two clients have separate budgets', async () => {
    for (let i = 0; i < 120; i++) expect((await health('203.0.113.10')).status).toBe(200);
    expect((await health('203.0.113.10')).status).toBe(429);
    expect((await health('198.51.100.20')).status).toBe(200);
  });

  it('the test-error hook requires an admin token', async () => {
    const res = await request(app).post('/api/v1/admin/__test-error').set('X-Forwarded-For', '192.0.2.1');
    expect(res.status).toBe(401);
  });
});
