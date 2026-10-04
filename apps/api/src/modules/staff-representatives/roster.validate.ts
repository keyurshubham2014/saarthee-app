/**
 * Roster row rules shared by the CSV importer and staff CRUD (TASK-09 §5.2, REQ-F-045, REQ-S-012).
 */
import type { RepRole } from '@prisma/client';
import { checkOfficePhone, MOBILE_REFUSED_MESSAGE } from '../representatives/phone';

export const ROSTER_HEADER = [
  'name_en', 'name_gu', 'role', 'party_text', 'term_start', 'term_end', 'ward_number', 'ac_number',
  'office_phone', 'public_email', 'source_url', 'last_verified_at',
] as const;

export const CONSTITUENCY_HEADER = ['ac_number', 'ac_name_en', 'ac_name_gu', 'pc_name_en', 'pc_name_gu', 'ward_numbers', 'source_url'] as const;

export const MAX_CORPORATORS_PER_WARD = 4;

export interface RosterRecord {
  nameEn: string;
  nameGu: string;
  role: RepRole;
  partyText: string | null;
  termStart: Date;
  termEnd: Date | null;
  wardNumber: number | null;
  acNumbers: number[];
  publicPhone: string | null;
  publicEmail: string | null;
  sourceUrl: string;
  lastVerifiedAt: Date;
}

const DATE = /^\d{4}-\d{2}-\d{2}$/;
const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function parseDate(v: string): Date | null {
  if (!DATE.test(v)) return null;
  const d = new Date(`${v}T00:00:00.000Z`);
  return Number.isNaN(d.getTime()) || d.toISOString().slice(0, 10) !== v ? null : d;
}

export function isHttpsUrl(v: string): boolean {
  try {
    return new URL(v).protocol === 'https:' && v.startsWith('https://');
  } catch {
    return false;
  }
}

/** Validates one raw roster row; returns the record or the list of `field: message` errors. */
export function validateRosterRow(raw: Record<string, string>, today = new Date()): { ok: true; record: RosterRecord } | { ok: false; errors: string[] } {
  const errors: string[] = [];
  const v = (k: string) => (raw[k] ?? '').trim();
  const nameEn = v('name_en');
  const nameGu = v('name_gu');
  if (nameEn.length < 2 || nameEn.length > 120) errors.push('name_en: must be 2–120 characters.');
  if (nameGu.length < 2 || nameGu.length > 120) errors.push('name_gu: must be 2–120 characters.');
  const role = v('role') as RepRole;
  if (!['corporator', 'mla', 'mp'].includes(role)) errors.push('role: must be corporator, mla or mp.');
  const partyText = v('party_text') || null;
  if (partyText && partyText.length > 80) errors.push('party_text: at most 80 characters.');
  const termStart = parseDate(v('term_start'));
  if (!termStart) errors.push('term_start: must be a date like 2026-03-01.');
  const termEnd = v('term_end') ? parseDate(v('term_end')) : null;
  if (v('term_end') && !termEnd) errors.push('term_end: must be a date like 2031-02-28.');
  if (termStart && termEnd && termEnd <= termStart) errors.push('term_end: must be after term_start.');

  let wardNumber: number | null = null;
  let acNumbers: number[] = [];
  const wardRaw = v('ward_number');
  const acRaw = v('ac_number');
  if (role === 'corporator') {
    wardNumber = /^\d{1,2}$/.test(wardRaw) ? Number(wardRaw) : null;
    if (wardNumber === null || wardNumber < 1 || wardNumber > 48) errors.push('ward_number: corporators need a ward number 1–48.');
    if (acRaw) errors.push('ac_number: leave empty for corporators.');
  } else if (role === 'mla' || role === 'mp') {
    if (wardRaw) errors.push('ward_number: leave empty for MLAs and MPs.');
    acNumbers = acRaw.split(';').map((s) => s.trim()).filter(Boolean).map(Number);
    if (acNumbers.length === 0 || acNumbers.some((n) => !Number.isInteger(n) || n < 1 || n > 400)) {
      errors.push('ac_number: must be an assembly constituency number (MPs: a list like 44;45;46).');
    } else if (role === 'mla' && acNumbers.length !== 1) {
      errors.push('ac_number: an MLA has exactly one assembly constituency.');
    }
  }

  const phone = checkOfficePhone(v('office_phone'));
  let publicPhone: string | null = null;
  if (phone.kind === 'mobile') errors.push(`office_phone: ${MOBILE_REFUSED_MESSAGE}`);
  else if (phone.kind === 'invalid') errors.push('office_phone: must be an Ahmedabad office landline like 079 2658 1234.');
  else if (phone.kind === 'landline') publicPhone = phone.e164;

  const email = v('public_email').toLowerCase() || null;
  if (email && (email.length > 254 || !EMAIL.test(email))) errors.push('public_email: must be an official email address.');

  const sourceUrl = v('source_url');
  if (!sourceUrl) errors.push('source_url: every row needs a source link.');
  else if (!isHttpsUrl(sourceUrl) || sourceUrl.length > 500) errors.push('source_url: must be an https:// link.');

  const lastVerifiedAt = parseDate(v('last_verified_at'));
  if (!lastVerifiedAt) errors.push('last_verified_at: must be a date like 2026-09-12.');
  else if (lastVerifiedAt.getTime() > today.getTime()) errors.push('last_verified_at: cannot be in the future.');

  if (errors.length > 0) return { ok: false, errors };
  return {
    ok: true,
    record: {
      nameEn, nameGu, role, partyText, termStart: termStart!, termEnd, wardNumber, acNumbers, publicPhone,
      publicEmail: email, sourceUrl, lastVerifiedAt: lastVerifiedAt!,
    },
  };
}

/** Import upsert key: (role, lower(name_en), term_start). */
export function rosterKey(r: { role: string; nameEn: string; termStart: Date }): string {
  return `${r.role}|${r.nameEn.toLowerCase()}|${r.termStart.toISOString().slice(0, 10)}`;
}
