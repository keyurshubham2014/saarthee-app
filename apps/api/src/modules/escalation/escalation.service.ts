/**
 * POST /issues/{id}/escalations (V2 TASK-06 §5.3, REQ-F-025): prepares a pre-filled, evidence-linked message
 * and targets for one ladder level; logs an `escalated` event and moves `reported → sent` through
 * transition(). Sending is done by the citizen (relay via TASK-09, email, phone, copy/share).
 */
import type { Prisma } from '@prisma/client';
import { config } from '../../config';
import { now as clockNow } from '../../lib/clock';
import { prisma } from '../../lib/db';
import { AppError } from '../../lib/errors';
import type { AuthenticatedUser } from '../../middleware/requireUser';
import { deriveIssue } from '../issues/derive';
import { transitionInTx, type TransitionResult } from '../lifecycle/lifecycle.service';
import { OPEN_STATUSES } from '../lifecycle/transitions';
import { INDEPENDENCE_NOTE, LEVELS, renderEscalation, type EscalationLevel, type Lang } from './templates';

const DAY_MS = 86_400_000;

export interface EscalationTarget {
  kind: 'relay' | 'email' | 'phone';
  representativeId?: string;
  label: string;
  email?: string;
  phone?: string;
  sourceUrl?: string;
}

/** corporators until the first escalation; then the next level once the last one is ≥ 7 days old and still overdue. */
export function recommendLevel(previous: { level: EscalationLevel; at: Date }[], overdue: boolean, now: Date): EscalationLevel {
  if (previous.length === 0) return 'corporators';
  const highest = previous.reduce((a, b) => (LEVELS.indexOf(b.level) >= LEVELS.indexOf(a.level) ? b : a));
  const idx = LEVELS.indexOf(highest.level);
  const lastAt = Math.max(...previous.filter((p) => p.level === highest.level).map((p) => p.at.getTime()));
  if (overdue && now.getTime() - lastAt >= 7 * DAY_MS && idx < LEVELS.length - 1) return LEVELS[idx + 1]!;
  return highest.level;
}

async function targetsFor(level: EscalationLevel, lang: Lang, issue: { wardId: string | null; zoneId: string | null }): Promise<EscalationTarget[]> {
  if (level === 'corporators') {
    if (!issue.wardId) return [];
    const areas = await prisma.representativeArea.findMany({
      where: { wardId: issue.wardId, representative: { role: 'corporator', isActive: true } },
      select: { representative: { select: { id: true, nameEn: true, nameGu: true } } },
    });
    return areas.map(({ representative: r }) => ({ kind: 'relay', representativeId: r.id, label: lang === 'gu' ? r.nameGu : r.nameEn }));
  }
  const out: EscalationTarget[] = [];
  if (level === 'zone_office' && issue.wardId) {
    const ward = await prisma.ward.findUnique({ where: { id: issue.wardId }, select: { officePhone: true, sourceUrl: true } });
    if (ward?.officePhone) out.push({ kind: 'phone', label: lang === 'gu' ? 'વોર્ડ કચેરી' : 'Ward office', phone: ward.officePhone, sourceUrl: ward.sourceUrl });
  }
  const contacts = await prisma.escalationContact.findMany({
    where: { level, isActive: true, OR: level === 'commissioner' ? [{ zoneId: null }] : [{ zoneId: issue.zoneId }, { zoneId: null }] },
    orderBy: { zoneId: { sort: 'asc', nulls: 'last' } },
  });
  const contact = contacts[0];
  if (contact) {
    const label = lang === 'gu' ? contact.titleGu : contact.titleEn;
    if (contact.email) out.push({ kind: 'email', label, email: contact.email, sourceUrl: contact.sourceUrl });
    if (contact.phone) out.push({ kind: 'phone', label, phone: contact.phone, sourceUrl: contact.sourceUrl });
  }
  return out;
}

async function assertEscalationQuota(userId: string, now: Date): Promise<void> {
  const n = await prisma.issueEvent.count({ where: { actorId: userId, type: 'escalated', createdAt: { gt: new Date(now.getTime() - DAY_MS) } } });
  if (n >= config.QUOTA_ESCALATIONS_PER_DAY) {
    throw new AppError('RATE_LIMITED', { message: 'You have reached the daily limit. Please try again later.', details: [{ field: 'quota', issue: 'escalations_per_day' }] });
  }
}

export async function prepareEscalation(user: AuthenticatedUser, issueId: string, level: EscalationLevel, lang: Lang) {
  const issue = await prisma.issue.findUnique({
    where: { id: issueId },
    include: { category: { select: { nameEn: true, nameGu: true, slaDays: true } }, ward: { select: { nameEn: true, nameGu: true } } },
  });
  if (!issue) throw new AppError('NOT_FOUND');
  const isReporter = issue.reporterId === user.id;
  const follows = isReporter || (await prisma.follow.count({ where: { issueId, userId: user.id } })) > 0;
  if (!follows || user.role !== 'citizen') throw new AppError('FORBIDDEN');
  if (!OPEN_STATUSES.includes(issue.status)) throw new AppError('ISSUE_NOT_OPEN');
  const now = clockNow();
  await assertEscalationQuota(user.id, now);

  const prevEvents = await prisma.issueEvent.findMany({ where: { issueId, type: 'escalated' }, select: { meta: true, createdAt: true } });
  const previous = prevEvents
    .map((e) => ({ level: (e.meta as { level?: EscalationLevel } | null)?.level, at: e.createdAt }))
    .filter((p): p is { level: EscalationLevel; at: Date } => !!p.level && LEVELS.includes(p.level));
  const recommendedLevel = recommendLevel(previous, deriveIssue(issue, now).isOverdue, now);

  const evidenceUrl = `${config.PUBLIC_WEB_BASE_URL.replace(/\/$/, '')}/i/${issue.id}`;
  const reportedOn = new Intl.DateTimeFormat(lang === 'gu' ? 'gu-IN' : 'en-IN', { timeZone: 'Asia/Kolkata', day: 'numeric', month: 'short', year: 'numeric' }).format(issue.createdAt);
  const { subject, message } = renderEscalation(level, lang, {
    wardEn: issue.ward?.nameEn ?? 'Ahmedabad', wardGu: issue.ward?.nameGu ?? 'અમદાવાદ', catEn: issue.category.nameEn, catGu: issue.category.nameGu,
    reportedOn, evidenceUrl, status: issue.status, daysOpen: Math.max(0, Math.floor((now.getTime() - issue.createdAt.getTime()) / DAY_MS)),
    slaDays: issue.category.slaDays, meTooCount: issue.meTooCount,
  });
  const targets = await targetsFor(level, lang, issue);

  let pending: TransitionResult | null = null;
  await prisma.$transaction(async (tx: Prisma.TransactionClient) => {
    await tx.issueEvent.create({ data: { issueId, actorId: user.id, actorRole: 'citizen', type: 'escalated', meta: { level }, createdAt: now } });
    if (issue.status === 'reported') {
      const actor = isReporter ? { userId: user.id, kind: 'reporter' as const } : { userId: null, kind: 'system' as const };
      pending = await transitionInTx(tx, issueId, 'sent', actor, { note: `escalated:${level}` });
    }
  });
  if (pending) await (pending as TransitionResult).afterCommit();
  return { level, recommendedLevel, subject, message, evidenceUrl, targets, independenceNote: INDEPENDENCE_NOTE[lang] };
}
