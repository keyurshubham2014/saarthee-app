/**
 * Escalation message templates `escalation.<level>.<lang>` (V2 TASK-06 §5.3, REQ-F-025). Gujarati drafted
 * for native review. Messages never contain the resident's name, phone or id.
 */
import type { IssueStatus } from '@prisma/client';

export const LEVELS = ['corporators', 'zone_office', 'deputy_commissioner', 'commissioner'] as const;
export type EscalationLevel = (typeof LEVELS)[number];
export type Lang = 'gu' | 'en';

export interface TemplateVars {
  wardEn: string;
  wardGu: string;
  catEn: string;
  catGu: string;
  reportedOn: string;
  evidenceUrl: string;
  status: IssueStatus;
  daysOpen: number;
  slaDays: number;
  meTooCount: number;
}

/** Status words as the app shows them (ARB status*), used as a label: "status: In progress" / "સ્થિતિ: કામ ચાલુ". */
const STATUS_WORD: Record<Lang, Partial<Record<IssueStatus, string>>> = {
  en: { reported: 'reported', sent: 'sent to AMC', acknowledged: 'acknowledged', in_progress: 'in progress', reopened: 'reopened' },
  gu: { reported: 'નોંધાઈ', sent: 'AMC ને મોકલાઈ', acknowledged: 'સ્વીકારાઈ', in_progress: 'કામ ચાલુ', reopened: 'ફરી ખૂલી' },
};

const GREETING: Record<Lang, Record<EscalationLevel, string>> = {
  en: {
    corporators: 'Dear Corporator',
    zone_office: 'Dear Zone Office team',
    deputy_commissioner: 'Dear Deputy Municipal Commissioner',
    commissioner: 'Dear Municipal Commissioner',
  },
  gu: {
    corporators: 'આદરણીય કોર્પોરેટરશ્રી',
    zone_office: 'આદરણીય ઝોન ઑફિસ',
    deputy_commissioner: 'આદરણીય ડેપ્યુટી મ્યુનિસિપલ કમિશનરશ્રી',
    commissioner: 'આદરણીય મ્યુનિસિપલ કમિશનરશ્રી',
  },
};

export const INDEPENDENCE_NOTE: Record<Lang, string> = {
  en: 'Saarthee prepares this message for you. It is not an official complaint. Saarthee is an independent citizen app and is not run by AMC.',
  gu: 'સારથી તમારા માટે આ સંદેશ તૈયાર કરે છે. આ સત્તાવાર ફરિયાદ નથી. સારથી સ્વતંત્ર નાગરિક એપ છે અને AMC દ્વારા ચલાવાતી નથી.',
};

export function renderEscalation(level: EscalationLevel, lang: Lang, v: TemplateVars): { subject: string; message: string } {
  const status = STATUS_WORD[lang][v.status] ?? v.status;
  if (lang === 'en') {
    return {
      subject: `Overdue civic issue in ward ${v.wardEn} — ${v.catEn}`,
      message:
        `${GREETING.en[level]}, a ${v.catEn.toLowerCase()} problem reported on ${v.reportedOn} at ${v.evidenceUrl} is still ${status} ` +
        `after ${v.daysOpen} days (Saarthee target: ${v.slaDays} days). ${v.meTooCount === 1 ? '1 resident is' : `${v.meTooCount} residents are`} affected. ` +
        `Please arrange for it to be fixed. — A resident of ${v.wardEn}, sent via Saarthee (independent citizen app, not an official AMC complaint).`,
    };
  }
  return {
    subject: `વોર્ડ ${v.wardGu}માં બાકી નાગરિક સમસ્યા — ${v.catGu}`,
    message:
      `${GREETING.gu[level]}, ${v.reportedOn}ના રોજ નોંધાયેલી ‘${v.catGu}’ની સમસ્યા (${v.evidenceUrl}) ${v.daysOpen} દિવસ પછી પણ ઉકેલાઈ નથી ` +
      `(હાલની સ્થિતિ: ${status}; સારથી લક્ષ્ય: ${v.slaDays} દિવસ). ${v.meTooCount === 1 ? '1 રહેવાસી' : `${v.meTooCount} રહેવાસીઓ`} અસરગ્રસ્ત છે. ` +
      `કૃપા કરીને તેને ઉકેલવાની વ્યવસ્થા કરશો. — ${v.wardGu}ના એક રહેવાસી, સારથી દ્વારા મોકલેલ (સ્વતંત્ર નાગરિક એપ, AMC ની સત્તાવાર ફરિયાદ નથી).`,
  };
}
