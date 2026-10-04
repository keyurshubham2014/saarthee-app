/** TASK-08 test helpers: fixture wards (1, 2 west; 3 east), staff tokens, composer bodies, alert flows. */
import type { UserRole } from '@prisma/client';
import { prisma } from '../../src/lib/db';
import { signUserToken } from '../../src/lib/tokens';
import { api } from '../helpers/app';
import { makeUser } from '../helpers/factories';
import { importFixtureWards } from '../geo/helpers';

export const PREFIX = '/api/v1';

export async function wardsFixture() {
  await importFixtureWards();
  const wards = await prisma.ward.findMany({ orderBy: { number: 'asc' }, include: { zone: true } });
  const zones = await prisma.zone.findMany({ orderBy: { code: 'asc' } });
  const byNumber = (n: number) => wards.find((w) => w.number === n)!;
  const zone = (code: string) => zones.find((z) => z.code === code)!;
  return { wards, zones, byNumber, zone };
}

export async function staffUser(role: UserRole, data: Parameters<typeof makeUser>[0] = {}) {
  const user = await makeUser({ role, displayName: `${role} ${Math.random().toString(36).slice(2, 6)}`, ...data });
  const { accessToken } = signUserToken(user);
  return { user, auth: { Authorization: `Bearer ${accessToken}` } };
}

export const ist = (local: string) => new Date(`${local}+05:30`);

export function composer(target: Record<string, unknown>, extra: Record<string, unknown> = {}, from = new Date()) {
  return {
    type: 'water_cut',
    severity: 'advisory',
    titleEn: 'Water supply cut in Alpha',
    titleGu: 'આલ્ફામાં પાણી પુરવઠો બંધ',
    bodyEn: 'No water supply from 10:00 to 16:00 due to pipeline repair.',
    bodyGu: 'પાઇપલાઇન સમારકામને કારણે 10:00 થી 16:00 પાણી પુરવઠો બંધ રહેશે.',
    sourceName: 'AMC Water Department',
    sourceUrl: 'https://ahmedabadcity.gov.in',
    validFrom: from.toISOString(),
    validTo: new Date(from.getTime() + 6 * 3_600_000).toISOString(),
    target,
    ...extra,
  };
}

type Auth = Record<string, string>;

export async function createDraft(auth: Auth, body: Record<string, unknown>): Promise<string> {
  const res = await api().post(`${PREFIX}/staff/alerts`).set(auth).send(body);
  if (res.status !== 201) throw new Error(`create failed ${res.status} ${JSON.stringify(res.body)}`);
  return res.body.id as string;
}

export const act = (auth: Auth, id: string, action: string, body?: object) =>
  api().post(`${PREFIX}/staff/alerts/${id}/${action}`).set(auth).send(body ?? {});

/** Draft → submit → approvals → publish; returns the alert id and the publish response body. */
export async function publishFlow(body: Record<string, unknown>, approvers: Auth[], publisher: Auth) {
  const id = await createDraft(approvers[0]!, body);
  const s = await act(approvers[0]!, id, 'submit');
  if (s.status !== 200) throw new Error(`submit ${s.status} ${JSON.stringify(s.body)}`);
  for (const a of approvers) {
    const r = await act(a, id, 'approve');
    if (r.status !== 200) throw new Error(`approve ${r.status} ${JSON.stringify(r.body)}`);
  }
  const p = await act(publisher, id, 'publish');
  if (p.status !== 200) throw new Error(`publish ${p.status} ${JSON.stringify(p.body)}`);
  return { id, body: p.body as Record<string, unknown> };
}
