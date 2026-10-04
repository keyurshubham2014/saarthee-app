/**
 * Ward search rules (V2 TASK-02 §5.3 `q`, §5.4 ward_search.dart) — identical in API and app:
 * - case-insensitive; spaces, hyphens and punctuation ignored;
 * - Gujarati digits ૦–૯ count as 0–9;
 * - leading "ward" / "વોર્ડ" / "no." / "નં." prefixes ignored ("ward 15", "વોર્ડ ૧૫");
 * - a query that is only digits matches the ward number exactly; anything else is a substring match on the
 *   English or Gujarati name.
 */
const GU_DIGITS = '૦૧૨૩૪૫૬૭૮૯';

export function toAsciiDigits(s: string): string {
  return s.replace(/[૦-૯]/g, (d) => String(GU_DIGITS.indexOf(d)));
}

/** Lower-case, NFC, no spaces/punctuation (keeps letters, Gujarati combining marks and digits). */
export function compact(s: string): string {
  return s
    .normalize('NFC')
    .toLowerCase()
    .replace(/[^\p{L}\p{M}\p{N}]+/gu, '');
}

export type WardQuery = { kind: 'all' } | { kind: 'number'; number: number } | { kind: 'text'; text: string };

export function parseWardQuery(raw: string | undefined | null): WardQuery {
  let q = toAsciiDigits((raw ?? '').normalize('NFC')).trim().toLowerCase();
  q = q.replace(/^(ward|વોર્ડ)\s*(no\.?|number|નં\.?|નંબર)?\s*/u, '').replace(/^(no\.?|નં\.?)\s*/u, '');
  const text = compact(q);
  if (!text) return { kind: 'all' };
  if (/^\d+$/.test(text)) return { kind: 'number', number: Number(text) };
  return { kind: 'text', text };
}

export interface SearchableWard {
  number: number;
  nameEn: string;
  nameGu: string;
}

export function wardMatches(w: SearchableWard, q: WardQuery): boolean {
  switch (q.kind) {
    case 'all':
      return true;
    case 'number':
      return w.number === q.number;
    case 'text':
      return compact(w.nameEn).includes(q.text) || compact(w.nameGu).includes(q.text);
  }
}
