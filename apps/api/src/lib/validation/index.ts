import { z } from 'zod';
import { config } from '../../config';

/**
 * Indian mobile rule (03 §4.2): remove spaces and dashes and an optional +91, 91 or 0 prefix;
 * the rest must be exactly 10 digits starting with 6–9. Returns E.164 (+91XXXXXXXXXX) or null.
 */
export function normalizeIndianMobile(input: string): string | null {
  let s = input.replace(/[\s-]/g, '');
  if (s.startsWith('+91')) s = s.slice(3);
  else if (s.length === 12 && s.startsWith('91')) s = s.slice(2);
  else if (s.length === 11 && s.startsWith('0')) s = s.slice(1);
  return /^[6-9]\d{9}$/.test(s) ? `+91${s}` : null;
}

/** CCRS normalization (03 §4.1): uppercase, spaces and dashes removed. */
export function normalizeCcrs(raw: string): string {
  return raw.trim().toUpperCase().replace(/[\s-]/g, '');
}

export const MSG = {
  phone: 'Enter a valid 10-digit Indian mobile number.',
  ccrs: 'Enter the complaint number you got from AMC.',
  photoExpired: 'Your photo upload expired. Please retake the photo.',
  clock: "Your phone's clock looks wrong. Please check the date and time.",
  location: "We couldn't read your location. Please try again.",
  consent: 'Please agree to the consent statement to continue.',
  note: 'Your note is too long.',
  reason: 'Choose a reason.',
  inviteCode: 'That code is invalid or already in use.',
} as const;

const CLOCK_SKEW_MS = 10 * 60_000;

const round6 = (n: number) => Math.round(n * 1e6) / 1e6;

/** Shared evidence fields for reports and verifications (03 §2.3, §4.2). */
export const evidenceFields = {
  latitude: z.number({ error: MSG.location }).min(-90, MSG.location).max(90, MSG.location).transform(round6),
  longitude: z.number({ error: MSG.location }).min(-180, MSG.location).max(180, MSG.location).transform(round6),
  gpsAccuracyM: z.number({ error: MSG.location }).min(0, MSG.location).max(999999).optional(),
  deviceCapturedAt: z.iso
    .datetime({ offset: true, error: MSG.clock })
    .transform((v) => new Date(v))
    .refine((d) => d.getTime() <= Date.now() + CLOCK_SKEW_MS, MSG.clock),
  platform: z.enum(['android', 'ios']),
  appVersion: z.string().trim().min(1).max(20),
};

export const consentVersionSchema = z
  .string({ error: MSG.consent })
  .refine((v) => config.CONSENT_TEXT_VERSIONS.includes(v), MSG.consent);
