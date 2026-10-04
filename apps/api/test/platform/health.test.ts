// T-01-10 (AC-3): /health reports the PostGIS version; 503 when the database is unreachable.
import { PrismaClient } from '@prisma/client';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { prisma } from '../../src/lib/db';
import { checkHealth } from '../../src/modules/public/health.service';
import { api } from '../helpers/app';
import { resetDb } from '../helpers/db';

beforeEach(resetDb);
afterEach(() => vi.restoreAllMocks());

describe('GET /health', () => {
  it('returns 200 with db up and the PostGIS version', async () => {
    const res = await api().get('/api/v1/health');
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ status: 'ok', db: 'up', postgis: expect.stringMatching(/^3\.([5-9]|\d{2,})\./) });
  });

  it('returns 503 SERVICE_UNAVAILABLE when the database is unreachable', async () => {
    vi.spyOn(prisma, '$queryRaw').mockRejectedValueOnce(new Error('connection refused'));
    const res = await api().get('/api/v1/health');
    expect(res.status).toBe(503);
    expect(res.body.error.code).toBe('SERVICE_UNAVAILABLE');
  });

  it('checkHealth() is null for a client pointed at a dead server', async () => {
    const dead = new PrismaClient({ datasourceUrl: 'postgresql://nobody:nothing@127.0.0.1:1/none_test' });
    try {
      expect(await checkHealth(dead, 3000)).toBeNull();
    } finally {
      await dead.$disconnect();
    }
  });
});
