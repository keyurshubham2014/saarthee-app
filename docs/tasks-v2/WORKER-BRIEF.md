# Saarthee v2 — worker brief (read before your task file)

You are a worker in the v2 build run by an integrator (see `GOAL-V2-PROMPT.md`). Work fully autonomously: never ask questions. When the task file is silent, choose what its spec section recommends and log `ASSUMPTION:` in the task's §5.6.

## Read order
1. `docs/tasks-v2/00-task-summary.md` (conventions, protocol, Open Questions row 7 = binding cross-task contracts).
2. `docs/v2/design-system.md` (Neem v2.2) — for any mobile/web UI work.
3. Your task file, and only the `Spec §n` / `DS §n` sections it names (`docs/v2/saarthee-v2-spec.md`).

## Git
- You run in your own worktree. First: `git checkout <your branch>` as given in your prompt (create it with `git checkout -b` if it does not exist). If your prompt names upstream branches to start from, `git merge` them first.
- Commit small and often: `V2-TASK-NN: <what landed>`, ending with the line `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`.
- Never commit `.env`, `.env.test`, `.claude/`, build outputs, secrets, real phone numbers, OTPs, tokens. Anchor `.gitignore` paths (`/photos/`).
- Do not push. Do not merge into `main` — the integrator does that.

## Environment (shared machine — be a good neighbour)
- Postgres+PostGIS: Docker on `127.0.0.1:5433`, credentials in `/Users/keyurpatel/Documents/Projects/LDRP-ITR/apps/api/.env` (and `infra/.env`). In your worktree create `apps/api/.env` and `apps/api/.env.test` by copying that file and pointing `DATABASE_URL` at **your own databases**: `saarthee_dev_<taskNN>` and `saarthee_test_<taskNN>` (create them with `CREATE DATABASE` via `docker exec saarthee-db-1 psql -U <user>`; `CREATE EXTENSION postgis` where needed). Never drop or migrate the `saarthee` database itself.
- Photo storage: a directory under `/Users/keyurpatel/saarthee-data/<taskNN>/` (outside the repo).
- Do **not** start anything on port 4000 and do **not** use the Android emulator, `adb`, `flutter run`, `flutter build apk/appbundle` or Gradle — the integrator owns the single emulator and the builds. Use Vitest + Supertest (in-process) and `flutter test`.
- Firebase: never create real projects. Use the Firebase Auth Emulator (`npx firebase-tools emulators:start --only auth`, pick a non-default port if 9099 is busy) or a verifier interface with a fake in tests.
- Run `npm ci` in `apps/api` and `flutter pub get` in `apps/mobile` in your worktree as needed. Check any new library on npm/pub.dev and pin exact versions.

## File ownership (prevents merge conflicts)
- API: only `apps/api/src/modules/<your module>/**`, `apps/api/test/<your module>/**`, new migrations with a unique timestamp prefix. Shared files (`src/app.ts`/`routes.ts` mounting, `src/lib/errors` codes, `prisma/schema.prisma`, `prisma/seed/index.ts` registration) — **append only**.
- Mobile: only `apps/mobile/lib/features/<feature>/**` and its tests. Router entries, ARB keys (a `<feature>`-prefixed block, `app_en.arb` and `app_gu.arb` together), staff navigation registry — **append only**. `lib/core/**`, theme and router skeleton belong to TASK-03; if you truly need a core change, keep it minimal and additive and say so in your report.
- Docs: update only your own task file (§5.6, §13, §14, status/progress) and **your own task's rows** in `coverage-verification.md`. The integrator owns `00-task-summary.md`.

## Definition of done for a worker
- Implementation steps of your task done; tests named in its §8 written in the same commits; all pass.
- API: `npx tsc --noEmit`, `npx eslint .`, `npm test` green. Mobile: `dart analyze` (0 errors/warnings), `dart format --set-exit-if-changed lib test`, `flutter test` green. No `Duration(` literals in `lib/features/**` (use `SaartheeMotion`). No hard-coded colours/strings (Neem tokens + ARB en+gu).
- Things only verifiable on the emulator: set the task status to `In Review`, mark those coverage rows `Not Verified` and list exact click-steps for the integrator in your final report. Never mark anything `Pass` you did not verify.
- Founder-blocked items (real Firebase, Play Console, hosting, real roster, IMD access, native Gujarati/legal review, physical phone): build everything possible, then mark `Deferred — needs <exact action>`.
- Blocked > 10 minutes on one item: skip it, log it in §13, continue.

## Final report (your last message)
Branch name and last commit; commits list; test counts (pass/fail) and static-check results; ASSUMPTIONs; deferred items; exact emulator verification steps for the integrator; any shared-file edits the integrator must watch when merging.
