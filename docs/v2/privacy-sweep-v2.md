# Saarthee v2 — privacy and security sweep (TASK-14 Phase C)

**Date:** 2026-10-04 · **Branch:** `v2/task-14-privacy` · **Worker:** W-T14P · Steps 11–13 of `docs/tasks-v2/TASK-14-e2e-launch.md`

## 1. How it was run

```bash
# API on its own port with a file log (apps/api/.env in the worktree):
#   API_PORT=4100 LOG_LEVEL=info LOG_FILE_DIR=<worktree>/.privacy-run/logs EMAIL_DRIVER=file
#   EMAIL_FILE_DIR=<worktree>/.privacy-run/mail JOBS_ENABLED=false STAFF_WEB_ORIGINS= (DATABASE_URL = shared dev DB `saarthee`)
npm --prefix apps/api start                   # tsx --env-file=.env src/server.ts → :4100
# Firebase Auth Emulator already running on 127.0.0.1:9099, project demo-saarthee
npm run privacy:check                         # = node scripts/privacy-checks.mjs [baseUrl] [--v1] [--v2]
```

- Script: `scripts/privacy-checks.mjs` (entry) + `scripts/privacy/{lib,auth,v1,v2-setup,v2-public,v2-account,v2-lifecycle}.mjs`.
  Default `--v2`; `--v1` runs the 14 legacy TASK-10 checks unchanged (they target the retired v1 endpoints).
  Base URL defaults to `http://localhost:$API_PORT/api/v1`. One `PASS`/`FAIL`/`SKIP` line per check, exit 1 on any FAIL, 2 on a crash.
- Sign-in: phone OTP on the Auth Emulator REST API (code read from `/emulator/v1/projects/demo-saarthee/verificationCodes`) →
  `POST /auth/firebase`. Citizens A/B/C are fictional `+919000000061/62/63`; staff are the seeded moderator `+919000000025`
  and representative `+919000000027`; admin is the v1 email login with `SEED_ADMIN_EMAIL`/`SEED_ADMIN_PASSWORD` read from `apps/api/.env`.
  Nothing secret is printed: tokens, OTPs, FCM token, relay bodies and the comment note are only held in memory and grepped for by P2-04.
- DB-side assertions (P2-03 stored rows, P2-06 tombstone/photo rows/files) use `DATABASE_URL` when reachable; on staging they are skipped and the API-side assertions still run.
- Fixtures per run: A reports a `roads` issue in Navrangpura with an EXIF+GPS JPEG, registers a device with an FCM token, follows it,
  sets a `=HYPERLINK(...)` CCRS number (CSV formula probe), relays a message without phone opt-in; B Me-toos/follows A's issue,
  claims an unverified Navrangpura corporator with a private evidence photo, relays with phone opt-in; the representative comments on A's issue.
  A and B delete their accounts in P2-06; C files 11 issues in P2-11 and deletes the account. Test rows were purged afterwards (§4).

## 2. Result (final run, 2026-10-04T11:55Z)

```
> privacy:check
> node scripts/privacy-checks.mjs

privacy-checks against http://localhost:4100/api/v1 (v2) at 2026-10-04T11:55:30.549Z

v2 fixtures ready (run 0fd414ca, ward Navrangpura)

PASS  P2-01 public issue views hide the reporter — 6 views, reporter shown as "A resident of Navrangpura"
PASS  P2-02 representative views expose only public contact fields — 6 representative details + ward list
PASS  P2-03 relay shows the citizen phone only with opt-in
PASS  P2-05 GET /me/export returns only the caller’s data — sections: exportedAt,format,profile,consents,devices,notifications,issues,me_toos,follows,issue_verifications,rep_messages,alert_subscriptions,rsvps,rep_claims
PASS  P2-07 alerts carry source and validity; warnings have two approvers — 1 public alerts, 3 published warning/critical
PASS  P2-08 staff CSV exports carry no phone; formula cells escaped
PASS  P2-09 claim evidence photo is admin-only, no-store
PASS  P2-10 stored issue photo has no EXIF/GPS/Make/Model
PASS  P2-06 DELETE /me erases identity, anonymises issues, removes photos, revokes session — 2 photos checked
SKIP  P2-12 HTTPS only on staging — local run over http — staging only (Deferred: needs hosting)
PASS  P2-11 public reads 429 after 120/IP/min; 11th issue in a day 429 — /categories first 429 at #121; /issues first 429 at #117; issues: 201,201,201,201,201,201,201,201,201,201,429:RATE_LIMITED
PASS  P2-04 API log holds no phone, token, OTP, relay body or comment — 75 KiB of log, 20 secrets checked

11 passed, 0 failed, 1 skipped (12 checks)
```

Order of execution: P2-06 deletes the accounts, P2-11 exhausts this IP's read budgets (so it runs last of the HTTP checks), and P2-04 is a
pure log read after every request of the run. `/issues` reaches 429 at #117 because the run had already made 3 list/detail reads in that minute.

### First run (before the fixes) — 7 PASS, 4 FAIL, 1 SKIP

| Check | Failure | Real defect? | Resolution |
|---|---|---|---|
| P2-06 | B's rep-claim evidence photo still served to admin after `DELETE /me`; photo row not deleted; file still on disk | **Yes** — erasure only collected report and verification photos | Fixed in `54bd2aa`: `apps/api/src/modules/rep-claims/privacy.ts` registers a `rep_claims` erasure step (evidence + loose `rep_evidence` photos removed after commit, claimant note cleared, pending claim withdrawn) and a `rep_claims` export section; Vitest `test/representatives/t14-claims-privacy.test.ts` |
| P2-02 | `officePhone` key flagged | No — script: the AMC ward office line is public (as in P2-01); only `publicPhone`/`publicEmail`/`officePhone` allowed | Script corrected, all other phone/email/user/claim keys still forbidden |
| P2-03 | Opt-in phone "missing" from the outgoing email | No — script read the raw `.eml`, whose parts are base64 | Script decodes MIME base64 parts before searching |
| P2-07 | `GET /alerts` 400 | No — script used `?ward=`; the API takes `?wards=` | Script fixed; also lists `active=false` |

## 3. SQL audits (§5.2, shared dev DB `saarthee`, after the purge)

| Audit | Result |
|---|---|
| Issue statuses in the seed | reported 9, sent 3, acknowledged 2, in_progress 1, marked_fixed 2, verified 4, reopened 6, rejected 1, merged 1 — all 7 public statuses present |
| Phone-like strings `issue_events.note` | **0** |
| Phone-like strings `notifications` | **0** (contract query names `body`; the table has `title_en/title_gu/body_en/body_gu`, all four searched) |
| `events.properties ~* 'phone\|token\|\+91'` | **0** |
| Extra: `rep_messages` without opt-in, `issues.description` | 0, 0 |
| Published alerts without source/validity | **0 rows** |
| Services with `link_ok = false` | 0 rows |
| Staff readiness (active) | moderator 1, admin 0 in `users` (admin is the v1 `admin_users` login) — pilot item, TASK-14 Phase G |
| Pilot wards (Naranpura, Nava Vadaj, Navrangpura, Paldi, Vasna) | 4 corporators each, 0 missing source, oldest check 22 days, 1–2 constituencies (seed data, not the real roster) |

## 4. Test data hygiene

Each run creates 3 fictional citizens (all end `deleted`) and 12 issues. They were purged from the shared dev DB after the runs
(`issues`, `rep_claims`, `photos`, `users` rows of those 9 accounts; `SET LOCAL saarthee.legacy_write = 'on'` was needed for the
append-only `issue_events` cascade). Photo files were already removed by `DELETE /me`. The seeded moderator and representative were only
signed in, not changed. Relay e-mails went to the worktree's `.privacy-run/mail` (git-ignored), not the shared mail directory.

## 5. Dependencies (`npm audit --audit-level=high`, apps/api)

11 findings: 8 moderate, 3 high. **High (accepted with note):** `prisma` → `@prisma/config` → `deepmerge-ts < 8`
(GHSA-ggr8-5vv4-36mx, stack exhaustion merging recursive object graphs). It is in the Prisma **CLI** config loader, which only merges our
own static `package.json#prisma` settings at migrate/generate time; no request data reaches it and `@prisma/client` at runtime is not
affected. The only offered fix is a downgrade to `prisma@6.12.0` (flagged semver-major) — not taken; re-check on the next Prisma upgrade.
Moderate: `uuid < 11.1.1` via `firebase-admin` → Google Cloud libraries (buffer bounds check when a caller passes `buf`; those libraries do
not) — accepted, fix needs a breaking `firebase-admin` change. `flutter pub outdated` and Dependabot are outside this worker's scope
(mobile/GitHub settings) and left to the integrator.

## 6. Not covered here

- **P2-12** (HTTPS-only on staging) — SKIP locally; **Deferred — needs founder hosting** (staging domain + TLS). The script's sign-in
  helper speaks the Auth Emulator REST API only; a staging run needs a real Firebase project with test numbers and a sign-in path for them
  (e.g. ID tokens minted by the app on a test device, passed in). Until then a staging run prints `FAIL P2-setup` (no emulator) and
  still executes P2-12.
- `--v1` was not re-run: its endpoints (`/reports`, `/admin/complaints`, `/verify/complaint`) are v1 legacy; it is kept for the legacy tables only.
