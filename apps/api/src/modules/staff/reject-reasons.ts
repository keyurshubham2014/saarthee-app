/**
 * Moderator reject reasons (TASK-10 §5.3) and their citizen-facing labels, worded as the app's
 * `staffReject*` ARB strings. The `rejected` event note is stored as `<reason>` or `<reason>: <moderator note>`.
 */
export const REJECT_REASONS = ['spam', 'duplicate', 'out_of_area', 'private_individual', 'not_civic', 'other'] as const;
export type RejectReason = (typeof REJECT_REASONS)[number];

export const REASON_TEXT: Record<RejectReason, { en: string; gu: string }> = {
  spam: { en: 'Spam', gu: 'સ્પામ' },
  duplicate: { en: 'Duplicate', gu: 'ડુપ્લિકેટ' },
  out_of_area: { en: 'Outside city wards', gu: 'શહેરના વોર્ડની બહાર' },
  private_individual: { en: 'About a private person', gu: 'ખાનગી વ્યક્તિ વિશે' },
  not_civic: { en: 'Not a civic issue', gu: 'નાગરિક સમસ્યા નથી' },
  other: { en: 'Other reason', gu: 'અન્ય કારણ' },
};

/** "duplicate: see #12" → "ડુપ્લિકેટ: see #12" (gu) / "Duplicate: see #12" (en); unknown notes are returned as-is. */
export function rejectionReasonText(note: string | null, lang: 'en' | 'gu'): string | null {
  if (!note) return null;
  const m = /^([a-z_]+)(?::\s*([\s\S]*))?$/.exec(note);
  const label = m && (REASON_TEXT as Record<string, { en: string; gu: string }>)[m[1]!];
  if (!label) return note;
  return m[2] ? `${label[lang]}: ${m[2]}` : label[lang];
}
