// T-01-09 (AC-10): shared public limiter (120/IP/min) and test isolation via resetRateLimitStores().
import { beforeEach, describe, expect, it } from 'vitest';
import { resetRateLimitStores } from '../../src/middleware/rateLimit';
import { api } from '../helpers/app';
import { resetDb } from '../helpers/db';

beforeEach(resetDb);

describe('rate limits', () => {
  it('returns 429 RATE_LIMITED with Retry-After on the 121st /health call in a minute', async () => {
    for (let i = 0; i < 120; i++) {
      const ok = await api().get('/api/v1/health');
      expect(ok.status).toBe(200);
    }
    const res = await api().get('/api/v1/health');
    expect(res.status).toBe(429);
    expect(res.body.error.code).toBe('RATE_LIMITED');
    expect(Number(res.headers['retry-after'])).toBeGreaterThan(0);
  });

  it('starts every test with empty counters', async () => {
    for (let i = 0; i < 121; i++) await api().get('/api/v1/health');
    expect((await api().get('/api/v1/health')).status).toBe(429);
    await resetRateLimitStores();
    expect((await api().get('/api/v1/health')).status).toBe(200);
  });
});
