/** TASK-07 test helpers: public issues with photos in fixture wards, seeded PII to scan for. */
import type { Prisma } from '@prisma/client';
import { prisma } from '../../src/lib/db';
import { api } from '../helpers/app';
import { categoryId, ownedPhoto } from '../issues/helpers';
import { openIssue, user, ward } from '../lifecycle/helpers';

export { api, categoryId, openIssue, user, ward };
export { seedReference, DAY, INSIDE } from '../lifecycle/helpers';

/** Distinctive PII strings: no public response may contain them. */
export const PII = { name: 'Zorawar Testreporter', phone: '+919999912345' };

export async function piiReporter() {
  return user('citizen', { displayName: PII.name, phoneE164: PII.phone } as Partial<Prisma.UserUncheckedCreateInput>);
}

/** Public issue with a report photo; `over` overrides columns (createdAt, status, meTooCount…). */
export async function photoIssue(reporterId: string, over: Partial<Prisma.IssueUncheckedCreateInput> & { wardNumber?: number; category?: string } = {}) {
  const { category, ...rest } = over;
  const issue = await openIssue(reporterId, { ...(category ? { categoryId: await categoryId(category) } : {}), ...rest });
  const photoId = await ownedPhoto(reporterId, { blurApplied: true });
  await prisma.issuePhoto.create({ data: { issueId: issue.id, photoId, kind: 'report' } });
  return { issue, photoId };
}

export const get = (path: string, auth?: Record<string, string>) => (auth ? api().get(path).set(auth) : api().get(path));
