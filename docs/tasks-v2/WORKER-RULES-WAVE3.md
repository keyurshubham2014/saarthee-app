# Wave 3+ worker rules (read after WORKER-BRIEF.md)

Stall prevention (subagents on this machine get killed by a 600 s stream watchdog):
- NEVER use run_in_background; run every command in the foreground with the Bash `timeout` parameter (≤ 600000 ms).
- Keep each Write/Edit under ~150 lines; one tool call per response; short reasoning; commit after every green step.
- Read big files in ≤ 120-line chunks. Never read `docs/v2/design-preview.html` or other large HTML.

Environment on main (all merged): TASK-01 platform + test harness, TASK-02 wards/geo (`resolveWard()`, `OUTSIDE_SERVICE_AREA` 422),
TASK-03 Neem design system/shell/motion (`lib/core/**`), TASK-04 accounts/privacy/push (`requireUser`/`optionalUser`/`requireRole`,
`notifications` table, push service with `memory`/`log` drivers, app `ensureSignedIn`, `AuthGateway` over the Auth Emulator),
TASK-13 deployment (per-row photo `storageDriver`, config `superRefine`), V2-BRAND identity.
- API setup in your worktree: copy `/Users/keyurpatel/Documents/Projects/LDRP-ITR/apps/api/.env` and `.env.test` into `apps/api/`,
  point them at `saarthee_dev_<taskNN>`, `saarthee_test_<taskNN>`, `saarthee_shadow_<taskNN>`; `npm ci`; `npm run test:db:create`;
  `npx vitest run` must be green before you start (203 tests on main).
- Mobile: `flutter pub get && flutter test` (196 on main). Only Neem tokens, `SaartheeIcons`, `SaartheeMotion`, core widgets. ARB keys in
  a block prefixed with your feature name, in BOTH app_en.arb and app_gu.arb (Gujarati drafted, `"x-review": "pending"`).
- Job runner contract (summary Open Question 7): TASK-06 owns `src/jobs`. In wave 3 **W-ALR (TASK-08) creates `apps/api/src/jobs`**
  following TASK-06's contract (read TASK-06 §5 for it) and commits it first. Other wave-3 workers who need scheduled work export job
  definitions from their own module (`src/modules/<m>/jobs.ts` exporting `{ name, everyMs | cron, run }[]`) and do NOT edit `src/jobs`;
  the integrator registers them at merge.
- `amc_problem_types` belongs to TASK-05. `notifications` exists (TASK-04); extend it only additively via a new migration.
- Shared files are append-only: `src/routes.ts`, `src/lib/errors`, `src/lib/audit`, `prisma/schema.prisma`, `prisma/seed/index.ts`,
  `apps/mobile/lib/router/*`, ARB files.
- Do not use the emulator, adb, flutter build or port 4000. Final message = WORKER-BRIEF report with exact emulator steps.
