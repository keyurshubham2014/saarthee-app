/**
 * Issue-update fan-out (V2 TASK-06 §5.3, Spec §9, REQ-F-027). Recipients = followers (the reporter
 * auto-follows) minus the actor; one TASK-04 `notifyUser` row each (push + inbox) carrying both languages,
 * delivered in the recipient's language; held until 07:00 IST during quiet hours. Texts never name people.
 */
import type { IssueStatus } from '@prisma/client';
import { config } from '../../config';
import { now as clockNow } from '../../lib/clock';
import { prisma } from '../../lib/db';
import { logger } from '../../lib/logger';
import { notifyUser, type PushMessage } from '../../lib/push';
import { formatCityTime, quietHoursEnd } from '../../lib/time';

interface Names {
  catEn: string;
  catGu: string;
  wardEn: string;
  wardGu: string;
}

type Text = { en: string; gu: string };
type Template = (n: Names, extra: { days?: number; until?: Date }) => { title: Text; body: Text };

const at = (n: Names) => ({ en: `${n.catEn} in ${n.wardEn}`, gu: `${n.wardGu}માં ${n.catGu}` });

export const TEMPLATES: Partial<Record<IssueStatus | 'overdue' | 'ccrs_reminder', Template>> = {
  acknowledged: (n) => ({
    title: { en: 'Your issue was acknowledged', gu: 'તમારી સમસ્યા સ્વીકારાઈ' },
    body: { en: `${at(n).en} is now acknowledged.`, gu: `${at(n).gu} હવે સ્વીકારાઈ છે.` },
  }),
  in_progress: (n) => ({
    title: { en: 'Work has started', gu: 'કામ શરૂ થયું' },
    body: { en: `${at(n).en} is in progress.`, gu: `${at(n).gu} પર કામ ચાલુ છે.` },
  }),
  marked_fixed: (n) => ({
    title: { en: 'Is it fixed? Help check', gu: 'ઉકેલાયું? તપાસવામાં મદદ કરો' },
    body: {
      en: `${at(n).en} was marked fixed. If you're nearby, take a photo to confirm.`,
      gu: `${at(n).gu} ઉકેલાયેલ તરીકે ચિહ્નિત થયું. તમે નજીક હો તો ખાતરી માટે ફોટો લો.`,
    },
  }),
  verified: (n) => ({
    title: { en: 'Fix verified', gu: 'ઉકેલ ચકાસાયો' },
    body: { en: `Neighbours confirmed ${n.catEn} in ${n.wardEn} is fixed.`, gu: `પડોશીઓએ ખાતરી કરી કે ${at(n).gu} ઉકેલાઈ ગયું છે.` },
  }),
  reopened: (n) => ({
    title: { en: 'Issue reopened', gu: 'સમસ્યા ફરી ખોલાઈ' },
    body: { en: `${at(n).en} was reopened — it's not fixed yet.`, gu: `${at(n).gu} ફરી ખોલાયું — તે હજી ઉકેલાયું નથી.` },
  }),
  rejected: (n) => ({
    title: { en: 'Issue closed', gu: 'સમસ્યા બંધ કરાઈ' },
    body: { en: `${at(n).en} was closed by Saarthee moderators.`, gu: `${at(n).gu} સારથી મોડરેટરે બંધ કર્યું.` },
  }),
  overdue: (n, x) => ({
    title: { en: 'Past its target date', gu: 'લક્ષ્ય તારીખ વીતી ગઈ' },
    body: {
      en: `${at(n).en} is past Saarthee's ${x.days}-day target. You can escalate it.`,
      gu: `${at(n).gu} સારથીના ${x.days} દિવસના લક્ષ્ય કરતાં મોડું છે. તમે આગળ રજૂઆત કરી શકો છો.`,
    },
  }),
  ccrs_reminder: (_n, x) => ({
    title: { en: 'Reopen on AMC soon', gu: 'AMC પર જલ્દી ફરી ખોલો' },
    body: {
      en: `AMC closed your complaint. You can reopen it on AMC's site only until ${formatCityTime(x.until!, 'en')}.`,
      gu: `AMCએ તમારી ફરિયાદ બંધ કરી. તમે AMCની સાઇટ પર ${formatCityTime(x.until!, 'gu')} સુધી જ તેને ફરી ખોલી શકો છો.`,
    },
  }),
};

async function names(issueId: string): Promise<Names | null> {
  const i = await prisma.issue.findUnique({
    where: { id: issueId },
    select: { category: { select: { nameEn: true, nameGu: true } }, ward: { select: { nameEn: true, nameGu: true } } },
  });
  if (!i) return null;
  return { catEn: i.category.nameEn, catGu: i.category.nameGu, wardEn: i.ward?.nameEn ?? 'Ahmedabad', wardGu: i.ward?.nameGu ?? 'અમદાવાદ' };
}

/** Sends `kind` about `issueId` to `recipients` (or every follower when omitted), never to `actorUserId`. */
export async function notifyIssue(
  issueId: string,
  kind: keyof typeof TEMPLATES,
  opts: { actorUserId?: string | null; recipients?: string[]; days?: number; until?: Date; ignoreQuietHours?: boolean } = {},
): Promise<number> {
  const template = TEMPLATES[kind];
  const n = template && (await names(issueId));
  if (!template || !n) return 0;
  const userIds = opts.recipients ?? (await prisma.follow.findMany({ where: { issueId }, select: { userId: true } })).map((f) => f.userId);
  const recipients = [...new Set(userIds)].filter((u) => u !== opts.actorUserId);
  const { title, body } = template(n, opts);
  const sendAfter = opts.ignoreQuietHours ? undefined : (quietHoursEnd(clockNow(), config.QUIET_HOURS) ?? undefined);
  const msg: PushMessage = {
    kind: 'issue_update', refId: issueId, route: kind === 'marked_fixed' ? `/issues/${issueId}/verify` : `/issues/${issueId}`,
    title, body, channel: 'updates', sendAfter,
  };
  for (const userId of recipients) {
    try {
      await notifyUser(userId, msg);
    } catch (err) {
      logger.error({ issueId, kind, reason: err instanceof Error ? err.message : 'unknown' }, 'issue notification failed');
    }
  }
  return recipients.length;
}

/** Hooked by transition() after commit. `sent`/`merged` are not announced. */
export async function notifyStatusChange(issueId: string, to: IssueStatus, actorUserId: string | null): Promise<void> {
  if (!TEMPLATES[to]) return;
  await notifyIssue(issueId, to, { actorUserId });
}
