/**
 * AMC services directory seed (V2 TASK-12 §5.2, REQ-F-057). Production data: run by `npm run services:seed`
 * in every environment (insert-missing-only; `--force` overwrites from here).
 *
 * Source: every URL was found on the official Amdavad Municipal Corporation website (or the official site
 * it links to) on SERVICES_SOURCE.checkedOn and must pass `npm run services:check-links` before the pilot.
 * How-to steps are plain-language paraphrases of the official page; they never state fees or deadlines.
 * Gujarati copy is drafted by the implementer and awaits native review (summary Open Question #5).
 */
import { SERVICES_A } from './services-a';
import { SERVICES_B } from './services-b';
import { SERVICES_C } from './services-c';
import type { ServiceSeed } from './services-types';

export * from './services-types';

/** The 18 seeded services (17 active; `amc-schools` inactive until its URL is verified). */
export const SERVICES: readonly ServiceSeed[] = [...SERVICES_A, ...SERVICES_B, ...SERVICES_C];
