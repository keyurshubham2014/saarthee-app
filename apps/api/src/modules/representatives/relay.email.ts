/**
 * Relay email template (TASK-09 §5.3). Text + HTML; every user-supplied string is HTML-escaped. The citizen's
 * phone appears only when they ticked "share my phone"; the display name only when they set one.
 */
import { config } from '../../config';

export const INDEPENDENCE_LINE = 'Independent citizen app. Not run by or linked to AMC.';

interface RelayMail {
  subject: string;
  body: string;
  sharePhone: boolean;
  issueId: string | null;
  citizen: { displayName: string | null; phoneE164: string | null; homeWard: { number: number; nameEn: string } | null } | null;
}

export function escapeHtml(s: string): string {
  return s.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]!);
}

/** Header-safe: no CR/LF in the subject line. */
function oneLine(s: string): string {
  return s.replace(/[\r\n]+/g, ' ').trim();
}

export function renderRelayEmail(m: RelayMail): { subject: string; text: string; html: string } {
  const ward = m.citizen?.homeWard;
  const who = ward ? `a resident of Ward ${ward.number} ${ward.nameEn}` : 'a resident of Ahmedabad';
  const subject = oneLine(`[Saarthee] Message from ${who}: ${m.subject}`);
  const issueUrl = m.issueId ? `${config.PUBLIC_WEB_BASE_URL.replace(/\/$/, '')}/issues/${m.issueId}` : null;
  const phoneLine =
    m.sharePhone && m.citizen?.phoneE164
      ? `The resident agreed to share their phone number: ${m.citizen.phoneE164}`
      : 'The resident chose not to share their phone number.';
  const nameLine = m.citizen?.displayName ? `From: ${m.citizen.displayName}` : null;
  const footer = [
    INDEPENDENCE_LINE,
    `Saarthee relays messages from residents. To stop receiving them, write to ${config.EMAIL_OPS_ADDRESS}.`,
  ];

  const text = [
    `You have a message from ${who}, sent through Saarthee.`,
    '',
    `Subject: ${oneLine(m.subject)}`,
    ...(nameLine ? [nameLine] : []),
    '',
    m.body,
    '',
    ...(issueUrl ? [`About this reported issue: ${issueUrl}`, ''] : []),
    phoneLine,
    '',
    '--',
    ...footer,
  ].join('\n');

  const p = (s: string) => `<p>${escapeHtml(s)}</p>`;
  const html = [
    '<!doctype html><html><body style="font-family:sans-serif;line-height:1.5">',
    p(`You have a message from ${who}, sent through Saarthee.`),
    `<p><strong>Subject:</strong> ${escapeHtml(oneLine(m.subject))}</p>`,
    ...(nameLine ? [p(nameLine)] : []),
    `<blockquote style="white-space:pre-wrap">${escapeHtml(m.body)}</blockquote>`,
    ...(issueUrl ? [`<p>About this reported issue: <a href="${escapeHtml(issueUrl)}">${escapeHtml(issueUrl)}</a></p>`] : []),
    p(phoneLine),
    '<hr>',
    ...footer.map((f) => `<p style="font-size:12px;color:#555">${escapeHtml(f)}</p>`),
    '</body></html>',
  ].join('\n');

  return { subject, text, html };
}
