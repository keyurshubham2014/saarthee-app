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
