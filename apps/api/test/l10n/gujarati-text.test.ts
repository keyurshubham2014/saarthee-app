// Gujarati server text: templates in both languages, language selection, Gujarati dates, seed hygiene.
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { describe, expect, it } from 'vitest';
import { V2_CATEGORIES } from '../../prisma/seed/v2-categories';
import { SERVICES } from '../../prisma/seed-data/services';
import { localized, parseAcceptLanguage, pickLang } from '../../src/lib/lang';
import { formatCityDate, formatCityTime } from '../../src/lib/time';
import { localRejectReason, AUTO_REJECT_REASON } from '../../src/modules/rep-claims/claims.service';
import { renderEscalation, INDEPENDENCE_NOTE, type TemplateVars } from '../../src/modules/escalation/templates';
import { localDescription } from '../../src/modules/issues/issues.schemas';
import { TEMPLATES } from '../../src/modules/lifecycle/notify';
import { REMINDER_TEMPLATES } from '../../src/modules/reminders/reminders.service';
import { renderRelayEmail } from '../../src/modules/representatives/relay.email';
import { REASON_TEXT, rejectionReasonText } from '../../src/modules/staff/reject-reasons';

const GUJARATI = /[઀-૿]/;
const DEVANAGARI = /[ऀ-ॿ]/;
/** Latin words allowed inside Gujarati text: acronyms and proper nouns the app also keeps in Latin. */
const ALLOWED_LATIN = /\b(AMC|AMTS|BRTS|RTI|NOC|TDO|nProcure|Search|UPI|IMD|NDMA|SACHET|PM|AM)\b/g;

/** Common hygiene for a Gujarati string: has Gujarati, no Devanagari, no doubled or stray spaces. */
function expectCleanGujarati(s: string, opts: { latinOk?: boolean } = {}) {
  expect(s, s).toMatch(GUJARATI);
  expect(s, s).not.toMatch(DEVANAGARI);
  expect(s, s).not.toMatch(/ {2}/);
  expect(s, s).not.toMatch(/ [.,:;!?]/);
  expect(s, s).not.toMatch(/AMC[઀-૿]/); // the app writes "AMC ની", not "AMCની"
  if (!opts.latinOk) expect(s.replace(ALLOWED_LATIN, ''), s).not.toMatch(/[A-Za-z]{2,}/);
}

describe('language selection', () => {
  it('parses Accept-Language by q-value; gu-IN and GU are Gujarati; other languages fall through', () => {
    expect(parseAcceptLanguage('gu-IN,gu;q=0.9,en;q=0.8')).toBe('gu');
    expect(parseAcceptLanguage('en-IN, gu;q=0.5')).toBe('en');
    expect(parseAcceptLanguage('hi-IN, GU;q=0.7, en;q=0.6')).toBe('gu');
    expect(parseAcceptLanguage('en;q=0, gu;q=0.1')).toBe('gu');
    expect(parseAcceptLanguage('hi-IN, *;q=0.5')).toBeNull();
    expect(parseAcceptLanguage('')).toBeNull();
    expect(parseAcceptLanguage(undefined)).toBeNull();
    expect(parseAcceptLanguage('gu;q=abc')).toBeNull();
  });

  it('explicit choice wins, then the header, then the fallback; empty Gujarati falls back to English', () => {
    expect(pickLang('en', 'gu')).toBe('en');
    expect(pickLang(undefined, 'gu-IN')).toBe('gu');
    expect(pickLang('fr', 'hi')).toBe('en');
    expect(pickLang(undefined, undefined, 'gu')).toBe('gu');
    expect(localized('gu', { en: 'Heat', gu: 'ગરમી' })).toBe('ગરમી');
    expect(localized('gu', { en: 'Heat', gu: '  ' })).toBe('Heat');
    expect(localized('en', { en: 'Heat', gu: 'ગરમી' })).toBe('Heat');
  });
});

describe('city dates and times', () => {
  const evening = new Date('2026-10-04T13:30:00Z'); // 19:00 IST, Sunday
  it('Gujarati: Gujarati weekday and month, Gujarati part of day, IST — never AM/PM', () => {
    expect(formatCityTime(evening, 'gu')).toBe('રવિ, 4 ઑક્ટો, સાંજે 7:00');
    expect(formatCityTime(new Date('2026-10-04T01:30:00Z'), 'gu')).toBe('રવિ, 4 ઑક્ટો, સવારે 7:00');
    expect(formatCityTime(new Date('2026-10-04T07:00:00Z'), 'gu')).toBe('રવિ, 4 ઑક્ટો, બપોરે 12:30');
    expect(formatCityTime(new Date('2026-10-04T18:35:00Z'), 'gu')).toBe('સોમ, 5 ઑક્ટો, રાત્રે 12:05');
    expect(formatCityTime(evening, 'gu')).not.toMatch(/AM|PM/i);
    expect(formatCityDate(evening, 'gu')).toBe('4 ઑક્ટો, 2026');
  });
  it('English unchanged', () => {
    expect(formatCityTime(evening, 'en')).toBe('Sun, 4 Oct, 7:00 pm');
    expect(formatCityDate(evening, 'en')).toBe('4 Oct 2026');
  });
});

describe('issue update templates (push + inbox)', () => {
  const names = { catEn: 'Water supply', catGu: 'પાણી પુરવઠો', wardEn: 'Paldi', wardGu: 'પાલડી' };
  const extra = { days: 7, until: new Date('2026-10-04T13:30:00Z') };
  it('every kind has a non-empty English and clean Gujarati title and body within push limits', () => {
    for (const [kind, t] of Object.entries(TEMPLATES)) {
      const { title, body } = t!(names, extra);
      for (const s of [title.en, body.en]) expect(s.length, kind).toBeGreaterThan(5);
      expectCleanGujarati(title.gu);
      expectCleanGujarati(body.gu);
      expect(body.gu.endsWith('.'), kind).toBe(true);
      expect(title.gu.length).toBeLessThanOrEqual(120);
      expect(body.gu.length).toBeLessThanOrEqual(400);
    }
  });
  it('Gujarati wording: quoted category, feminine agreement with સમસ્યા, app status words, IST deadline', () => {
    const t = (k: keyof typeof TEMPLATES) => TEMPLATES[k]!(names, extra);
    expect(t('acknowledged').body.gu).toBe('પાલડીમાં ‘પાણી પુરવઠો’ની સમસ્યા હવે સ્વીકારાઈ છે.');
    expect(t('in_progress').body.gu).toBe('પાલડીમાં ‘પાણી પુરવઠો’ની સમસ્યા પર કામ ચાલુ છે.');
    expect(t('marked_fixed').title.gu).toBe('ઉકેલાયું છે? તપાસવામાં મદદ કરો');
    expect(t('verified').body.gu).toBe('પડોશીઓએ ખાતરી કરી છે કે પાલડીમાં ‘પાણી પુરવઠો’ની સમસ્યા ઉકેલાઈ ગઈ છે.');
    expect(t('reopened').title.gu).toBe('સમસ્યા ફરી ખૂલી');
    expect(t('reopened').body.gu).toBe('પાલડીમાં ‘પાણી પુરવઠો’ની સમસ્યા ફરી ખૂલી છે — તે હજી ઉકેલાઈ નથી.');
    expect(t('overdue').body.gu).toContain('સારથીના 7 દિવસના લક્ષ્યમાં ઉકેલાઈ નથી');
    expect(t('ccrs_reminder').body.gu).toBe(
      'AMC એ તમારી ફરિયાદ બંધ કરી છે. જો સમસ્યા ઉકેલાઈ ન હોય, તો રવિ, 4 ઑક્ટો, સાંજે 7:00 સુધીમાં AMC ની સાઇટ પર ફરી ખોલો.',
    );
    expect(t('ccrs_reminder').body.en).toContain('Sun, 4 Oct, 7:00 pm');
    expect(t('acknowledged').body.en).toBe('Water supply in Paldi is now acknowledged.');
  });
});

describe('moderation reject reasons', () => {
  it('labels in both languages; event notes are localized, free text kept', () => {
    for (const r of Object.values(REASON_TEXT)) expectCleanGujarati(r.gu, { latinOk: false });
    expect(rejectionReasonText('duplicate', 'gu')).toBe('ડુપ્લિકેટ');
    expect(rejectionReasonText('duplicate', 'en')).toBe('Duplicate');
    expect(rejectionReasonText('out_of_area: near Gandhinagar', 'gu')).toBe('શહેરના વોર્ડની બહાર: near Gandhinagar');
    expect(rejectionReasonText('Something else', 'gu')).toBe('Something else');
    expect(rejectionReasonText(null, 'gu')).toBeNull();
  });
  it('representative auto-reject reason in the reader language; staff text unchanged', () => {
    expect(localRejectReason(AUTO_REJECT_REASON, 'gu')).toBe('આ પ્રતિનિધિ માટે બીજો દાવો મંજૂર થયો');
    expect(localRejectReason(AUTO_REJECT_REASON, 'en')).toBe(AUTO_REJECT_REASON);
    expect(localRejectReason('Evidence unclear', 'gu')).toBe('Evidence unclear');
  });
});

describe('structured descriptions of sensitive categories', () => {
  it('stored English label → Gujarati label for gu readers; free text untouched', () => {
    expect(localDescription('encroachment', 'Blocking the footpath', 'gu')).toBe('ફૂટપાથ રોકે છે');
    expect(localDescription('building', 'Unsafe building', 'gu')).toBe('અસુરક્ષિત મકાન');
    expect(localDescription('building', 'Unsafe building', 'en')).toBe('Unsafe building');
    expect(localDescription('roads', 'Blocking the footpath', 'gu')).toBe('Blocking the footpath');
    expect(localDescription('encroachment', null, 'gu')).toBeNull();
  });
});

describe('escalation message', () => {
  const vars: TemplateVars = {
    wardEn: 'Paldi', wardGu: 'પાલડી', catEn: 'Roads & potholes', catGu: 'રસ્તા અને ખાડા', reportedOn: '4 ઑક્ટો, 2026',
    evidenceUrl: 'https://saarthee.in/i/x', status: 'in_progress', daysOpen: 12, slaDays: 7, meTooCount: 1,
  };
  it('Gujarati: app status word as a label, singular resident, respectful request', () => {
    const { subject, message } = renderEscalation('corporators', 'gu', vars);
    expect(subject).toBe('વોર્ડ પાલડીમાં બાકી નાગરિક સમસ્યા — રસ્તા અને ખાડા');
    expect(message).toContain('4 ઑક્ટો, 2026ના રોજ નોંધાયેલી ‘રસ્તા અને ખાડા’ની સમસ્યા');
    expect(message).toContain('12 દિવસ પછી પણ ઉકેલાઈ નથી (હાલની સ્થિતિ: કામ ચાલુ; સારથી લક્ષ્ય: 7 દિવસ)');
    expect(message).toContain('1 રહેવાસી અસરગ્રસ્ત છે.');
    expect(message).toContain('કૃપા કરીને તેને ઉકેલવાની વ્યવસ્થા કરશો.');
    expectCleanGujarati(message, { latinOk: true });
    expect(renderEscalation('corporators', 'gu', { ...vars, meTooCount: 4 }).message).toContain('4 રહેવાસીઓ અસરગ્રસ્ત છે.');
    expectCleanGujarati(INDEPENDENCE_NOTE.gu);
  });
  it('English: singular and plural residents', () => {
    expect(renderEscalation('commissioner', 'en', vars).message).toContain('1 resident is affected.');
    expect(renderEscalation('commissioner', 'en', { ...vars, meTooCount: 3 }).message).toContain('3 residents are affected.');
  });
});

describe('relay email to representatives', () => {
  const m = {
    subject: 'Streetlight out', body: 'Please fix the light.', sharePhone: false, issueId: 'abc',
    citizen: { displayName: null, phoneE164: '+910000000000', homeWard: { number: 30, nameEn: 'Paldi', nameGu: 'પાલડી' } },
  };
  it('gu: Gujarati subject and text, respectful આપ, no English footer', () => {
    const mail = renderRelayEmail(m, 'gu');
    expect(mail.subject).toBe('[સારથી] વોર્ડ 30 પાલડીના એક રહેવાસીનો સંદેશ: Streetlight out');
    expect(mail.text).toContain('વોર્ડ 30 પાલડીના એક રહેવાસી તરફથી સારથી મારફતે આપના માટે સંદેશ આવ્યો છે.');
    expect(mail.text).toContain('રહેવાસીએ પોતાનો ફોન નંબર ન આપવાનું પસંદ કર્યું છે.');
    expect(mail.text).toContain('સ્વતંત્ર નાગરિક એપ. AMC દ્વારા ચલાવાતી નથી કે તેની સાથે જોડાયેલી નથી.');
    expect(mail.text).not.toContain('Independent citizen app');
    expect(mail.text).not.toContain('+910000000000');
  });
  it('en: unchanged English email', () => {
    const mail = renderRelayEmail(m, 'en');
    expect(mail.subject).toBe('[Saarthee] Message from a resident of Ward 30 Paldi: Streetlight out');
    expect(mail.text).not.toMatch(GUJARATI);
  });
  it('both (official inbox, no linked account): Gujarati first, English after, message once, English subject', () => {
    const mail = renderRelayEmail({ ...m, sharePhone: true }, 'both');
    expect(mail.subject).toBe('[Saarthee] Message from a resident of Ward 30 Paldi: Streetlight out');
    expect(mail.text.indexOf('આપના માટે સંદેશ')).toBeLessThan(mail.text.indexOf('You have a message'));
    expect(mail.text.split('Please fix the light.')).toHaveLength(2);
    expect(mail.text).toContain('રહેવાસીએ પોતાનો ફોન નંબર આપવાની સંમતિ આપી છે: +910000000000');
    expect(mail.html).toContain('વિષય:');
  });
});

describe('legacy follow-up reminder', () => {
  it('v2 is Gujarati first, then the v1 English text', () => {
    const v = { ccrsNumber: 'C-123', verifyLink: 'https://saarthee.in/v/t' };
    const text = REMINDER_TEMPLATES.v2!(v);
    expect(text.startsWith('નમસ્તે! લગભગ એક અઠવાડિયા પહેલાં તમે અમારી એપમાં AMC ફરિયાદ C-123 નોંધી હતી.')).toBe(true);
    expect(text.endsWith(REMINDER_TEMPLATES.v1!(v))).toBe(true);
  });
});

describe('seed and reference data', () => {
  it('category Gujarati names are Gujarati only and clean', () => {
    for (const c of V2_CATEGORIES) expectCleanGujarati(c.nameGu);
  });

  it('48 wards and 7 zones: Gujarati names in Gujarati script; zone names include ઝોન (the app shows them bare)', () => {
    const list = JSON.parse(readFileSync(path.resolve(__dirname, '../../prisma/data/geo/amc-ward-list.json'), 'utf8')) as {
      zones: { nameGu: string }[];
      wards: { nameGu: string }[];
    };
    expect(list.wards).toHaveLength(48);
    expect(list.zones).toHaveLength(7);
    for (const w of list.wards) expectCleanGujarati(w.nameGu);
    for (const z of list.zones) {
      expectCleanGujarati(z.nameGu);
      expect(z.nameGu.endsWith(' ઝોન')).toBe(true);
    }
  });

  it('services directory: every Gujarati field is clean and uses the app terms', () => {
    for (const s of SERVICES as unknown as Record<string, unknown>[]) {
      for (const [k, v] of Object.entries(s)) {
        if (!k.endsWith('Gu') || typeof v !== 'string' || v === 'AMC') continue; // a department named just "AMC"
        expectCleanGujarati(v, { latinOk: true });
        expect(v, `${String(s.slug)}.${k}`).not.toContain('કચેરી'); // app glossary: ઑફિસ
      }
    }
  });

  it('seed modules: no Devanagari, no "સાર્થી"/"ટૅપ" misspellings, no doubled zone word, sample markers kept', () => {
    const dir = path.resolve(__dirname, '../../prisma/seed/modules');
    for (const f of ['070-representatives.ts', '080-alerts.ts', '090-services.ts', '100-initiatives.ts', '110-escalation-contacts.ts', '120-rep-claims.ts']) {
      const src = readFileSync(path.join(dir, f), 'utf8');
      expect(src, f).not.toMatch(DEVANAGARI);
      expect(src, f).not.toMatch(/સાર્થી|ટૅપ|ઝોન ઝોન|nameGu} ઝોન/);
      expect(src, f).not.toMatch(/AMC[઀-૿]/);
    }
    const alerts = readFileSync(path.join(dir, '080-alerts.ts'), 'utf8');
    expect(alerts).toContain("sourceName: 'AMC (નમૂનો / sample)'");
    expect(alerts).not.toContain("'AMC (sample data)'");
  });
});
