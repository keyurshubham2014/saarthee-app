/**
 * Language selection for server-generated text. The app's two languages are Gujarati and English; anything
 * else falls back. Order: an explicit choice (`?lang=`, the user's saved language) → Accept-Language → default.
 */
export type AppLang = 'gu' | 'en';

const isLang = (v: unknown): v is AppLang => v === 'gu' || v === 'en';

/**
 * The best of 'gu' / 'en' in an Accept-Language header by q-value (RFC 9110 §12.5.4), or null when the
 * header names neither. "gu-IN", "gu" and "GU" all mean Gujarati; "*" is ignored; q=0 means "not this".
 */
export function parseAcceptLanguage(header: string | undefined | null): AppLang | null {
  if (!header) return null;
  let best: { lang: AppLang; q: number; index: number } | null = null;
  header.split(',').forEach((raw, index) => {
    const [tag = '', ...params] = raw.trim().split(';');
    const primary = tag.trim().toLowerCase().split('-')[0];
    if (!isLang(primary)) return;
    const qParam = params.map((p) => p.trim()).find((p) => p.toLowerCase().startsWith('q='));
    const q = qParam === undefined ? 1 : Number(qParam.slice(2));
    if (!Number.isFinite(q) || q <= 0 || q > 1) return;
    if (!best || q > best.q) best = { lang: primary, q, index };
  });
  return (best as { lang: AppLang } | null)?.lang ?? null;
}

/** Explicit choice if valid, else the Accept-Language preference, else `fallback`. */
export function pickLang(explicit: unknown, acceptLanguage: string | undefined | null, fallback: AppLang = 'en'): AppLang {
  if (isLang(explicit)) return explicit;
  return parseAcceptLanguage(acceptLanguage) ?? fallback;
}

/** Gujarati text when the recipient reads Gujarati and it is non-empty; otherwise the English text. */
export function localized(lang: AppLang | null | undefined, text: { en: string; gu: string | null | undefined }): string {
  return lang === 'gu' && text.gu && text.gu.trim() ? text.gu : text.en;
}
