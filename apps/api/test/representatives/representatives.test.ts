// T-09-01 (DB CHECKs) and T-09-02 (GET /wards/{id}/representatives, GET /representatives/{id}) — AC-1, AC-2, AC-7.
import { beforeEach, describe, expect, it } from 'vitest';
import { prisma } from '../../src/lib/db';
import { api } from '../helpers/app';
import { makeUser } from '../helpers/factories';
import { resetDb, sqlError } from '../helpers/db';
import { fixtureWards, makeAc, makeRep, SRC } from './helpers';

let wards: Map<number, string>;
beforeEach(async () => {
  await resetDb();
  wards = await fixtureWards();
});

describe('representatives constraints (T-09-01)', () => {
  const insert = `INSERT INTO representatives (name_en, name_gu, role, term_start, source_url, last_verified_at, public_phone, contact_consent_at)
    VALUES ('Test A', 'ટેસ્ટ', 'corporator', '2026-03-01', $1, '2026-09-01', $2, $3)`;

  it('accepts a 079 landline, refuses a mobile without consent, allows it only with contact consent', async () => {
    await prisma.$executeRawUnsafe(insert, SRC, '+917926581234', null);
    expect(await sqlError(insert.replace('Test A', 'Test B'), [SRC, '+919825012345', null])).toContain('ck_representatives_public_phone');
    await prisma.$executeRawUnsafe(insert.replace('Test A', 'Test C'), SRC, '+919000000001', new Date());
  });

  it('requires an https source URL and term_end after term_start', async () => {
    expect(await sqlError(insert, ['http://example.org', null, null])).toContain('ck_representatives_source_url');
    expect(
      await sqlError(
        `INSERT INTO representatives (name_en, name_gu, role, term_start, term_end, source_url, last_verified_at) VALUES ('Test D', 'ટેસ્ટ', 'mla', '2026-03-01', '2026-01-01', $1, '2026-09-01')`,
        [SRC],
      ),
    ).toContain('ck_representatives_term');
  });

  it('an area is exactly one of ward or assembly constituency', async () => {
    const rep = await makeRep({});
    const ac = await makeAc(44);
    const sql = 'INSERT INTO representative_areas (representative_id, ward_id, assembly_constituency_id) VALUES ($1::uuid, $2::uuid, $3)';
    expect(await sqlError(sql, [rep.id, wards.get(1), ac.id])).toContain('ck_representative_areas_one');
    expect(await sqlError(sql, [rep.id, null, null])).toContain('ck_representative_areas_one');
  });

  it('import key (role, lower(name_en), term_start) is unique', async () => {
    await makeRep({ nameEn: 'Same Name' });
    expect(
      await sqlError(
        `INSERT INTO representatives (name_en, name_gu, role, term_start, source_url, last_verified_at) VALUES ('SAME NAME', 'ટેસ્ટ', 'corporator', '2026-03-01', $1, '2026-09-01')`,
        [SRC],
      ),
    ).toContain('uq_representatives_import_key');
  });
});

describe('GET /wards/{id}/representatives (T-09-02)', () => {
  it('groups corporators, both MLAs of a 2-AC ward and the MP; hides inactive and private fields', async () => {
    const w1 = wards.get(1)!;
    const ac1 = await makeAc(44, [w1]);
    const ac2 = await makeAc(45, [w1]);
    const user = await makeUser({ phoneE164: '+919000000099' });
    for (const n of ['Dev', 'Asha', 'Chirag', 'Bina']) await makeRep({ nameEn: `${n} Test`, publicPhone: n === 'Asha' ? '+917926581234' : null, userId: n === 'Asha' ? user.id : null }, [{ wardId: w1 }]);
    await makeRep({ nameEn: 'Gone Test', isActive: false }, [{ wardId: w1 }]);
    await makeRep({ nameEn: 'Mla One', role: 'mla' }, [{ assemblyConstituencyId: ac1.id }]);
    await makeRep({ nameEn: 'Mla Two', role: 'mla' }, [{ assemblyConstituencyId: ac2.id }]);
    await makeRep({ nameEn: 'Mp One', role: 'mp', publicEmail: null }, [{ assemblyConstituencyId: ac1.id }, { assemblyConstituencyId: ac2.id }]);
    await makeRep({ nameEn: 'Other Ward' }, [{ wardId: wards.get(2)! }]);

    const res = await api().get(`/api/v1/wards/${w1}/representatives`);
    expect(res.status).toBe(200);
    expect(res.body.ward).toMatchObject({ id: w1, number: 1, assemblyConstituencyCount: 2 });
    expect(res.body.corporators.map((r: { nameEn: string }) => r.nameEn)).toEqual(['Asha Test', 'Bina Test', 'Chirag Test', 'Dev Test']);
    expect(res.body.corporators[0]).toMatchObject({ role: 'corporator', wardNumber: 1, initials: 'AT', canMessage: true, verified: false, partyText: 'Test Party' });
    expect(res.body.mlas.map((r: { nameEn: string }) => r.nameEn)).toEqual(['Mla One', 'Mla Two']);
    expect(res.body.mps).toHaveLength(1);
    expect(res.body.mps[0]).toMatchObject({ canMessage: false, acNameEn: 'Test Seat' });
    expect(res.body.electionMode).toMatchObject({ active: false });
    const text = JSON.stringify(res.body);
    for (const hidden of ['userId', 'user_id', 'contactConsentAt', 'claims', user.id, '9000000099']) expect(text).not.toContain(hidden);
  });

  it('404 for an unknown ward; 400 for a malformed id', async () => {
    expect((await api().get('/api/v1/wards/00000000-0000-4000-8000-000000000000/representatives')).status).toBe(404);
    expect((await api().get('/api/v1/wards/12/representatives')).status).toBe(400);
  });
});

describe('GET /representatives/{id} (T-09-02, AC-2)', () => {
  it('shows office phone, term, source and last checked; no private fields', async () => {
    const rep = await makeRep({ nameEn: 'Asha Test', publicPhone: '+917926581234', contactConsentAt: null }, [{ wardId: wards.get(1)! }]);
    const res = await api().get(`/api/v1/representatives/${rep.id}`);
    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({
      nameEn: 'Asha Test', officePhone: '+917926581234', termStart: '2026-03-01', termEnd: '2031-02-28', sourceUrl: SRC,
      lastVerifiedAt: '2026-09-12', canMessage: true, areas: [{ kind: 'ward', wardNumber: 1 }],
    });
    expect(Object.keys(res.body)).not.toContain('contactConsentAt');
    expect(Object.keys(res.body)).not.toContain('userId');
  });

  it('a representative without phone or email: no phone key and canMessage false; inactive → 404', async () => {
    const bare = await makeRep({ publicEmail: null }, [{ wardId: wards.get(1)! }]);
    const res = await api().get(`/api/v1/representatives/${bare.id}`);
    expect(res.body.canMessage).toBe(false);
    expect(res.body).not.toHaveProperty('officePhone');
    expect(res.body).not.toHaveProperty('publicEmail');
    const gone = await makeRep({ isActive: false });
    expect((await api().get(`/api/v1/representatives/${gone.id}`)).status).toBe(404);
  });
});
