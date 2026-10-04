/** TASK-06 test helpers: issues in fixture ward 1, staff/representative users, status/verify calls. */
import { randomUUID } from 'node:crypto';
import type { IssueStatus, Prisma, UserRole } from '@prisma/client';
import { prisma } from '../../src/lib/db';
import { api } from '../helpers/app';
import { makeIssue } from '../helpers/factories';
import { categoryId, citizen, INSIDE, ownedPhoto } from '../issues/helpers';

export { INSIDE, citizen, ownedPhoto };
export { seedReference } from '../issues/helpers';

export type Auth = Record<string, string>;
export const DAY = 86_400_000;

/** Point `metres` north of INSIDE (1° lat ≈ 110 574 m here). */
export const north = (metres: number) => ({ lat: Number((INSIDE.lat + metres / 110_574).toFixed(6)), lng: INSIDE.lng });

export async function ward(number: number) {
  return prisma.ward.findFirstOrThrow({ where: { number }, select: { id: true, zoneId: true, nameEn: true, nameGu: true } });
}

/** Issue in ward `wardNumber` at INSIDE, reported by `reporterId` (auto-followed). */
export async function openIssue(reporterId: string, data: Partial<Prisma.IssueUncheckedCreateInput> & { wardNumber?: number } = {}) {
  const { wardNumber = 1, ...rest } = data;
  const w = await ward(wardNumber);
  if (rest.status === 'merged' && !rest.mergedIntoId) rest.mergedIntoId = (await openIssue(reporterId)).id;
  const issue = await makeIssue({
    categoryId: await categoryId('roads'), reporterId, lat: INSIDE.lat, lng: INSIDE.lng, wardId: w.id, zoneId: w.zoneId,
    status: 'reported', followerCount: 1, ...rest,
  });
  await prisma.follow.create({ data: { issueId: issue.id, userId: reporterId } });
  return issue;
}

export async function user(role: UserRole = 'citizen', data: Partial<Prisma.UserUncheckedCreateInput> = {}) {
  return citizen({ role, ...data });
}

/** A representative user for `wardIds`; `verified=false` leaves the representative unverified. */
export async function representative(wardIds: string[], verified = true) {
  const u = await user('representative');
  const rep = await prisma.representative.create({
    data: {
      nameEn: `Sample Corporator ${u.user.id.slice(0, 6)}`, nameGu: 'નમૂનો કોર્પોરેટર', role: 'corporator', termStart: new Date('2021-03-01'),
      sourceUrl: 'https://example.org/reps', lastVerifiedAt: new Date('2026-10-01'), userId: u.user.id,
      verifiedAt: verified ? new Date() : null, areas: { create: wardIds.map((wardId) => ({ wardId })) },
    },
  });
  return { ...u, rep };
}

export function postStatus(auth: Auth, issueId: string, to: string, expectedStatus: IssueStatus | string, extra: Record<string, unknown> = {}) {
  return api().post(`/api/v1/issues/${issueId}/status`).set(auth).send({ to, expectedStatus, clientActionId: randomUUID(), ...extra });
}

export async function verifyBody(userId: string, answer: 'fixed' | 'not_fixed', metres = 40, extra: Record<string, unknown> = {}) {
  const at = north(metres);
  return {
    clientSubmissionId: randomUUID(), answer, photoId: await ownedPhoto(userId, { purpose: 'verification' }),
    latitude: at.lat, longitude: at.lng, gpsAccuracyM: 10, deviceCapturedAt: new Date().toISOString(), ...extra,
  };
}

export function postVerify(auth: Auth, issueId: string, body: Record<string, unknown>) {
  return api().post(`/api/v1/issues/${issueId}/verifications`).set(auth).send(body);
}

/** Marked fixed `daysAgo` days ago by `actorId` (event written as the lifecycle would). */
export async function markedFixedIssue(reporterId: string, daysAgo = 0, actorId: string | null = null) {
  const at = new Date(Date.now() - daysAgo * DAY);
  const issue = await openIssue(reporterId, { status: 'marked_fixed', markedFixedAt: at, statusChangedAt: at });
  await prisma.issueEvent.create({
    data: { issueId: issue.id, actorId, actorRole: actorId ? 'moderator' : 'system', type: 'status_change', fromStatus: 'in_progress', toStatus: 'marked_fixed', createdAt: at },
  });
  return issue;
}
