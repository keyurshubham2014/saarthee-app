/**
 * Office-phone guard shared by the roster importer and staff CRUD (TASK-09 §5.2, REQ-S-012).
 * Only an Ahmedabad 079 landline is accepted and stored as +9179XXXXXXXX. Every Indian mobile number
 * (10 digits starting 6–9, with or without +91/0) is refused — it cannot be told apart from a personal number.
 */
export type PhoneCheck =
  | { kind: 'empty' }
  | { kind: 'landline'; e164: string }
  | { kind: 'mobile' }
  | { kind: 'invalid' };

export const MOBILE_REFUSED_MESSAGE = 'Mobile numbers are never imported. Use an official office landline or leave it empty.';

export function checkOfficePhone(raw: string | null | undefined): PhoneCheck {
  const trimmed = (raw ?? '').trim();
  if (trimmed === '') return { kind: 'empty' };
  if (!/^[+\d\s().-]+$/.test(trimmed)) return { kind: 'invalid' };
  let digits = trimmed.replace(/\D/g, '');
  // A trunk-prefixed "0" or an explicit +91 marks an STD form; "079…" / "+91 79…" is the Ahmedabad code.
  let std = false;
  if (trimmed.startsWith('+') || (digits.length === 12 && digits.startsWith('91'))) {
    if (!digits.startsWith('91')) return { kind: 'invalid' };
    digits = digits.slice(2);
    std = true;
  } else if (digits.length === 11 && digits.startsWith('0')) {
    digits = digits.slice(1);
    std = true;
  }
  if (digits.length !== 10) return { kind: 'invalid' };
  if (std && digits.startsWith('79')) return { kind: 'landline', e164: `+91${digits}` };
  // Bare 10 digits starting 6–9 (or +91 + a non-079 number starting 6–9) is a mobile number.
  if (/^[6-9]/.test(digits)) return { kind: 'mobile' };
  return { kind: 'invalid' };
}
