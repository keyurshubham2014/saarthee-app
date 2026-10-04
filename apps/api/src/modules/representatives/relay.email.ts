/**
 * Relay email template (TASK-09 §5.3). Text + HTML; every user-supplied string is HTML-escaped. The citizen's
 * phone appears only when they ticked "share my phone"; the display name only when they set one.
 *
 * Language: a representative who has claimed their profile gets their app language ('gu' or 'en'); an official
 * inbox with no linked account gets 'both' (Gujarati first, then English, the resident's message once, English
 * subject line).
 */
import { config } from '../../config';

export const INDEPENDENCE_LINE = 'Independent citizen app. Not run by or linked to AMC.';
export const INDEPENDENCE_LINE_GU = 'સ્વતંત્ર નાગરિક એપ. AMC દ્વારા ચલાવાતી નથી કે તેની સાથે જોડાયેલી નથી.';

export type RelayMailLang = 'gu' | 'en' | 'both';

interface RelayMail {
  subject: string;
  body: string;
  sharePhone: boolean;
  issueId: string | null;
  citizen: {
    displayName: string | null;
    phoneE164: string | null;
    homeWard: { number: number; nameEn: string; nameGu?: string | null } | null;
  } | null;
}

export function escapeHtml(s: string): string {
  return s.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]!);
}

/** Header-safe: no CR/LF in the subject line. */
function oneLine(s: string): string {
  return s.replace(/[\r\n]+/g, ' ').trim();
}

function strings(m: RelayMail, issueUrl: string | null) {
  const ward = m.citizen?.homeWard;
  const whoEn = ward ? `a resident of Ward ${ward.number} ${ward.nameEn}` : 'a resident of Ahmedabad';
  const whoGu = ward ? `વોર્ડ ${ward.number} ${ward.nameGu || ward.nameEn}ના એક રહેવાસી` : 'અમદાવાદના એક રહેવાસી';
  const phone = m.sharePhone && m.citizen?.phoneE164 ? m.citizen.phoneE164 : null;
  const name = m.citizen?.displayName ?? null;
  return {
    en: {
      subject: `[Saarthee] Message from ${whoEn}: ${m.subject}`,
      intro: `You have a message from ${whoEn}, sent through Saarthee.`,
      subjectLabel: 'Subject:',
      name: name ? `From: ${name}` : null,
      issue: issueUrl ? 'About this reported issue:' : null,
      phone: phone ? `The resident agreed to share their phone number: ${phone}` : 'The resident chose not to share their phone number.',
      footer: [INDEPENDENCE_LINE, `Saarthee relays messages from residents. To stop receiving them, write to ${config.EMAIL_OPS_ADDRESS}.`],
    },
    gu: {
      subject: `[સારથી] ${whoGu}નો સંદેશ: ${m.subject}`,
      intro: `${whoGu} તરફથી સારથી મારફતે આપના માટે સંદેશ આવ્યો છે.`,
      subjectLabel: 'વિષય:',
      name: name ? `મોકલનાર: ${name}` : null,
      issue: issueUrl ? 'આ નોંધાયેલી સમસ્યા વિશે:' : null,
      phone: phone ? `રહેવાસીએ પોતાનો ફોન નંબર આપવાની સંમતિ આપી છે: ${phone}` : 'રહેવાસીએ પોતાનો ફોન નંબર ન આપવાનું પસંદ કર્યું છે.',
      footer: [INDEPENDENCE_LINE_GU, `સારથી રહેવાસીઓના સંદેશા પહોંચાડે છે. આવા સંદેશા બંધ કરાવવા ${config.EMAIL_OPS_ADDRESS} પર લખો.`],
    },
  };
}

export function renderRelayEmail(m: RelayMail, lang: RelayMailLang = 'both'): { subject: string; text: string; html: string } {
  const issueUrl = m.issueId ? `${config.PUBLIC_WEB_BASE_URL.replace(/\/$/, '')}/issues/${m.issueId}` : null;
  const all = strings(m, issueUrl);
  const langs = lang === 'both' ? (['gu', 'en'] as const) : ([lang] as const);
  const pick = <K extends keyof (typeof all)['en']>(k: K) => langs.map((l) => all[l][k]);
  const subject = oneLine(all[lang === 'gu' ? 'gu' : 'en'].subject);
  const subjectLine = (l: 'gu' | 'en') => `${all[l].subjectLabel} ${oneLine(m.subject)}`;

  const text = [
    ...pick('intro'),
    '',
    ...langs.map(subjectLine),
    ...pick('name').filter((s): s is string => s !== null),
    '',
    m.body,
    '',
    ...(issueUrl ? [...pick('issue').map((s) => `${s} ${issueUrl}`), ''] : []),
    ...pick('phone'),
    '',
    '--',
    ...langs.flatMap((l) => all[l].footer),
  ].join('\n');

  const p = (s: string) => `<p>${escapeHtml(s)}</p>`;
  const html = [
    '<!doctype html><html><body style="font-family:sans-serif;line-height:1.5">',
    ...pick('intro').map(p),
    ...langs.map((l) => `<p><strong>${escapeHtml(all[l].subjectLabel)}</strong> ${escapeHtml(oneLine(m.subject))}</p>`),
    ...pick('name').filter((s): s is string => s !== null).map(p),
    `<blockquote style="white-space:pre-wrap">${escapeHtml(m.body)}</blockquote>`,
    ...(issueUrl ? pick('issue').map((s) => `<p>${escapeHtml(s!)} <a href="${escapeHtml(issueUrl)}">${escapeHtml(issueUrl)}</a></p>`) : []),
    ...pick('phone').map(p),
    '<hr>',
    ...langs.flatMap((l) => all[l].footer).map((f) => `<p style="font-size:12px;color:#555">${escapeHtml(f)}</p>`),
    '</body></html>',
  ].join('\n');

  return { subject, text, html };
}
