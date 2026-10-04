# Seed expectations (hand count, REMINDER_INTERVAL_DAYS=7)

Sample complaints (all `app_version='seed'`, CCRS numbers `AMC-2026-00NN`; C11 = `amc 2026 0001`):

| # | Source | State | Reminders | Verifications |
|---|---|---|---|---|
| C1 | rwa | filed 10 d ago — due | 0 | 0 |
| C2 | rwa | filed 2 d ago — not due | 0 | 0 |
| C3 | rwa | reminded 8 d ago — due | 1 | 0 |
| C4 | rwa | verified | 1 | fixed |
| C5 | rwa | verified | 1 | not_fixed (note) |
| C6 | activist | verified twice | 1 | fixed, then not_fixed (latest) |
| C7 | activist | reminded 2 d ago — not due | 1 | 0 |
| C8 | activist | excluded (`test`) | 1 | not_fixed |
| C9 | social | verified, verification photo same sha256 as report photo | 1 | fixed |
| C10 | network | verified | 1 | not_fixed |
| C11 | unknown | filed 9 d ago — due, duplicate CCRS of C1 | 0 | 0 |

## `pilot_rates_v`

| group | complaints | reminded | verified | h1 | verifications | not_fixed | h2 |
|---|---|---|---|---|---|---|---|
| rwa | 5 | 3 | 2 | 0.667 | 2 | 1 | 0.500 |
| activist | 2 | 2 | 1 | 0.500 | 2 | 1 | 1.000 |
| trusted | 7 | 5 | 3 | 0.600 | 4 | 2 | 0.667 |
| social | 1 | 1 | 1 | 1.000 | 1 | 0 | 0.000 |
| network | 1 | 1 | 1 | 1.000 | 1 | 1 | 1.000 |
| unknown | 1 | 0 | 0 | null | 0 | 0 | null |

Statuses: filed C1, C2, C11; reminded C3, C7; verified_fixed C4, C9; verified_not_fixed C5, C6, C8, C10.
Due: C1, C3, C11 (3). Excluded: C8. Duplicate: C11.

**Demo delta:** sending a reminder to C1 and verifying it "Not fixed" moves rwa to reminded 4 / verified 3 /
h1 0.750 / not_fixed 2 / **h2 0.667**, and trusted to 6 / 4 / 0.667 / not_fixed 3 / **h2 0.750**.

Verified 2026-10-03 against the live view (exact match). If the seed changes, update this file in the same commit.

## v2 development seed (`npx prisma db seed`, V2 TASK-01 + TASK-02)

Modules run in file order (`prisma/seed/modules/`); a module whose tables do not exist logs
`Seed <name>: skipped (requires …)`. A second run changes nothing (`test/platform/seed.test.ts`, `test/geo/seed-wards.test.ts`).

| Table / fact | Expected |
|---|---|
| `categories` | 14 (dev fixture; TASK-05 replaces with reference data) |
| `users` | 6: 5 citizens (1 suspended) + 1 moderator; phones `+9190000000NN`, uids `seed-uid-NN`; mixed gu/en |
| `zones` / `wards` | 7 / 48 (OpenCity `opencity-amc-wards-2025-11` + AMC ward list) |
| Seeded issues | 12 (non-legacy) |
| Legacy issues | 11 (v1 fixtures C1–C11 via `legacy:migrate`), all `hidden`, no reporter |

Issues per status (seeded + legacy = total):

| Status | Seeded | Legacy | Total |
|---|---|---|---|
| reported | 3 (one hidden, one sensitive) | 3 | 6 |
| sent | 1 | 2 | 3 |
| acknowledged | 2 (one overdue) | 0 | 2 |
| in_progress | 1 | 0 | 1 |
| marked_fixed | 1 | 0 | 1 |
| verified | 1 | 2 | 3 |
| reopened | 1 | 4 | 5 |
| rejected | 1 | 0 | 1 |
| merged | 1 (→ issue 1) | 0 | 1 |

Issues per ward after the `wards` module's backfill (`geo:backfill checked=23 inside=23 nearest=0 outside=0`):

| Ward | Seeded | Legacy |
|---|---|---|
| 6 Nava Vadaj | 2 | 0 |
| 9 Naranpura | 2 | 0 |
| 18 Navrangpura | 2 | 2 |
| 21 Dariyapur | 0 | 9 |
| 30 Paldi | 4 | 0 |
| 31 Vasna | 2 | 0 |

Seeded issues sit only in the 5 pilot wards (Spec D5); legacy v1 fixtures keep their original coordinates.
Still skipped: `representatives` (TASK-09), `alerts` (TASK-08), `services`, `initiatives` (TASK-12).
Verified 2026-10-04 on a freshly migrated `saarthee_dev_task01`.
