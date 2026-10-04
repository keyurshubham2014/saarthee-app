// T-01-07 (AC-8, AC-10): retired v1 writes → 410; admin history reads need a token; anonymize still works.
import { randomUUID } from 'node:crypto';
import { beforeEach, describe, expect, it } from 'vitest';
import { prisma } from '../../src/lib/db';
import { migrateLegacyComplaints } from '../../src/lib/legacy/migrate';
import { api } from '../helpers/app';
import { createAdmin } from '../helpers/auth';
import { resetDb } from '../helpers/db';
import { makeCategory, makeCcrsCategory, makeComplaint } from '../helpers/factories';

beforeEach(resetDb);

const id = randomUUID();

describe('retired v1 writes', () => {
  const publicRoutes: [string, string][] = [
    ['post', '/api/v1/reports'],
    ['get', '/api/v1/verify/complaint'],
    ['get', '/api/v1/verify/complaint/photo'],
    ['post', '/api/v1/verify/photos'],
    ['post', '/api/v1/verify/submissions'],
    ['post', '/api/v1/invite-codes/validate'],
  ];
  it.each(publicRoutes)('%s %s → 410 ENDPOINT_RETIRED', async (method, path) => {
    const res = await (api() as unknown as Record<string, (p: string) => ReturnType<ReturnType<typeof api>['get']>>)[method]!(path).send({});
    expect(res.status).toBe(410);
    expect(res.body.error).toMatchObject({ code: 'ENDPOINT_RETIRED', message: 'Please update Saarthee to report issues.' });
  });

  const adminRoutes: [string, string][] = [
    ['post', '/api/v1/admin/categories'],
    ['patch', `/api/v1/admin/categories/${id}`],
    ['patch', `/api/v1/admin/complaints/${id}/exclusion`],
  ];
  it.each(adminRoutes)('admin %s %s → 410 ENDPOINT_RETIRED (with a valid token)', async (method, path) => {
    const { auth } = await createAdmin();
    const res = await (api() as unknown as Record<string, (p: string) => ReturnType<ReturnType<typeof api>['get']>>)[method]!(path)
      .set(auth)
      .send({ isExcluded: false, name: 'x', sortOrder: 1 });
    expect(res.status).toBe(410);
    expect(res.body.error.code).toBe('ENDPOINT_RETIRED');
  });
});

describe('admin history reads', () => {
  async function history() {
    const cat = await makeCcrsCategory('Streetlight');
    const complaint = await makeComplaint({ categoryId: cat.id });
    return { complaint };
  }

  it('need a token (401 without)', async () => {
    const { complaint } = await history();
    for (const path of ['/api/v1/admin/complaints', `/api/v1/admin/complaints/${complaint.id}`, '/api/v1/admin/export?type=complaints', '/api/v1/admin/rates', '/api/v1/admin/invite-codes', '/api/v1/admin/categories']) {
      const res = await api().get(path);
      expect(res.status, path).toBe(401);
    }
  });

  it('return 200 with a token', async () => {
    const { complaint } = await history();
    const { auth } = await createAdmin();
    const list = await api().get('/api/v1/admin/complaints').set(auth);
    expect(list.status).toBe(200);
    expect(list.body.items).toHaveLength(1);
    expect((await api().get(`/api/v1/admin/complaints/${complaint.id}`).set(auth)).status).toBe(200);
    const csv = await api().get('/api/v1/admin/export?type=complaints').set(auth);
    expect(csv.status).toBe(200);
    expect(csv.headers['content-type']).toContain('text/csv');
    // TASK-10 (D11): pilot-only rates and invite-code reads are removed (404); tested in test/staff/retired.test.ts.
    expect((await api().get('/api/v1/admin/categories').set(auth)).status).toBe(200);
  });

  it('anonymize still works (through the legacy bypass) and unlinks the imported issue photos', async () => {
    const { complaint } = await history();
    await makeCategory({ slug: 'streetlight' });
    await migrateLegacyComplaints(prisma);
    const issue = await prisma.issue.findUniqueOrThrow({ where: { legacyComplaintId: complaint.id }, include: { photos: true } });
    expect(issue.photos).toHaveLength(1);
    const { auth } = await createAdmin();
    const res = await api().post(`/api/v1/admin/complaints/${complaint.id}/anonymize`).set(auth).send({ confirm: true });
    expect(res.status).toBe(200);
    const after = await prisma.complaint.findUniqueOrThrow({ where: { id: complaint.id } });
    expect(after.phoneE164).toBeNull();
    expect(after.anonymizedAt).not.toBeNull();
    expect(await prisma.issuePhoto.count({ where: { issueId: issue.id } })).toBe(0);
    expect((await prisma.photo.findUniqueOrThrow({ where: { id: complaint.photoId } })).deletedAt).not.toBeNull();
  });
});
