/** Shared types and helpers for the TASK-12 services seed (kept apart to avoid an import cycle). */
export const SERVICE_CATEGORIES = [
  'tax',
  'certificates',
  'building',
  'health',
  'education',
  'transport',
  'leisure',
  'information',
  'business',
] as const;
export type ServiceCategory = (typeof SERVICE_CATEGORIES)[number];

export interface ServiceSeed {
  slug: string;
  category: ServiceCategory;
  nameEn: string;
  nameGu: string;
  department: string;
  departmentGu: string;
  summaryEn: string;
  summaryGu: string;
  /** Numbered Markdown list only ("1. …\n2. …"). */
  howToEn: string;
  howToGu: string;
  url: string;
  online: boolean;
  visitWardOffice: boolean;
  sortOrder: number;
  isActive: boolean;
}

/** Where the URLs came from and when they were found (stored on each active row as `verified_at`). */
export const SERVICES_SOURCE = {
  name: 'Amdavad Municipal Corporation website',
  homepage: 'https://ahmedabadcity.gov.in/',
  checkedOn: '2026-10-03',
} as const;

/** Joins steps into the numbered Markdown list stored in how_to_en / how_to_gu. */
export const steps = (...lines: string[]): string => lines.map((l, i) => `${i + 1}. ${l}`).join('\n');
