# Saarthee v2 — API contract, role and error-code sweep

TASK-14 §5.3 (endpoint groups 1–11, error-code sweep), §5.5 (role matrix), §6 steps 5–6. Worker W-T14A, branch
`v2/task-14-api-sweep`.

**Result: 305 checks, 305 PASS, 0 FAIL** (final run 2026-10-04 12:10 UTC, after the fixes below). First run:
266 checks, 19 FAIL (5 sweep assumptions corrected against the specs, the rest real defects, fixed).

## How to run

```bash
# 1. Own API instance (never 4000/4100): a copy of apps/api/.env with
#    API_PORT=4200  LOG_LEVEL=info  LOG_FILE_DIR=<abs>/var/sweep/logs  AUDIT_LOG_FILE=<abs>/var/sweep/audit/audit.log
#    JOBS_ENABLED=false  STAFF_WEB_ORIGINS=   (DATABASE_URL = shared dev DB `saarthee`)
cd apps/api && nohup ./node_modules/.bin/tsx --env-file=.env src/server.ts > ../../var/sweep/api.out 2>&1 &
# 2. Firebase Auth Emulator on 127.0.0.1:9099 (project demo-saarthee) must be running.
# 3. Sweep (restart the API first: the in-memory rate limits are part of what is tested)
npm run api:sweep -- http://127.0.0.1:4200/api/v1 [--report var/sweep/final.json] [--skip-env]
```

- `SWEEP_ENV_FILE` (default `apps/api/.env`) gives the admin login (`SEED_ADMIN_EMAIL` / `SEED_ADMIN_PASSWORD`), the
  audit/log file locations and the database used for cleanup. Values are never printed.
- Accounts: visitor (no token); citizens A/B/C/D/E on fictional `+91 90000 000 80–85` (signed in through the emulator,
  erased with `DELETE /me` at the end); moderator `…25`; representative `…27` (verified, ward 18); admin = v1 email login.
- Data hygiene: only the sweep's own rows are touched. Sweep issues are hidden, then their reporters erased; sweep
  alerts, initiative, service and roster entry are deleted; sample corporator 18-D is deactivated for one step (to free a
  ward seat) and restored in a `finally`. Leftover sweep accounts from an aborted run are erased first.
- 503 check: a throwaway instance on port 4201 with an unreachable `DATABASE_URL` (the shared database is never stopped).
- Runtime ≈ 3 min (one wait for the 10/IP/min sign-in window; 18 real startups for the env sweep).

## Fixes (each with a Vitest test)

| Commit | Defect found by the sweep | Fix | Test |
|---|---|---|---|
| `2131b2c` | v1 admin email login (the staff console's admin login) got **401** on `/staff/services`, `/staff/initiatives`, `/staff/tips`, `/staff/representatives`, `/staff/constituencies`, `/staff/settings/election-mode` — those TASK-09/12 routes used `requireUser + requireRole` instead of the TASK-10 §5.5 staff guard | `requireStaff(...)` on those routes; `created_by`/`updated_by`/`attendance_marked_by` (FKs to `users`) are `null` for an `admin_user` actor; audit actor from `req.staff` | `test/staff/t14-sweep-fixes.test.ts` |
| `2131b2c` | Moderator/admin `POST /issues/{id}/status` wrote its `staff_action` line to the main log only — **no line in `AUDIT_LOG_FILE`** (REQ-S-010) | `writeAudit` (both destinations, actor kind, role, target type/id, `extra.to`; idempotent replays not re-audited) | same file |
| `2131b2c` | Roster create/update/deactivate, ward–constituency mapping and election-mode changes (TASK-09 `staffAudit`) wrote to the main log only, with no `role`/`targetType`; election mode had no target | routed through `writeAudit` with actor kind, role, `targetType` (`representative`/`ward`/`setting`) and `targetId` (`election_mode` for the setting) | same file |
| `2131b2c` | 27 `src/config` variables missing from `apps/api/.env.example` | added with their defaults and comments | env sweep |
| `24016cd` | `DELETE /me` left a deleted citizen's **pending representative claim** in the admin queue (approvable), with the claimant's note; `GET /me/export` omitted claims | `rep-claims/privacy.ts`: export section `rep_claims`; erasure step withdraws pending claims and clears `claimant_note` | `test/representatives/t14-claims-privacy.test.ts` |
| `2131b2c` | `FLAG_QUOTA`, `INITIATIVE_STARTED`, `EXPORT_TOO_LARGE` were produced by no test or check by name | — (behaviour correct) | `test/staff/t14-error-codes.test.ts` |

Sweep assumptions corrected against the specs (not defects; the checks follow the spec): a reporter **may** answer
"Is it fixed?" on their own issue (TASK-06 §5.6); `CLAIM_ALREADY_PENDING` is per representative profile (TASK-11 DDL
`rep_claims_one_pending (representative_id, user_id)`); a representative's out-of-ward status change returns
`WARD_OUT_OF_SCOPE` (TASK-14 §5.3 row 11; the TASK-11 pre-transition hook runs first); a suspended user's existing
session gets 401 `TOKEN_REVOKED` because suspension bumps `token_version` (§5.5 allows 401/403; a new sign-in gets 403
`ACCOUNT_SUSPENDED`); moderators may **read** `/staff/services` (route allows admin + moderator; writes are admin-only).

Gates after the fixes (`apps/api`): `npx tsc --noEmit` clean, `npx eslint src test` clean,
`npx vitest run` **440 passed / 4 skipped** (baseline 433 / 4; +7 new tests).

## Results by group

| Group | Checks | Pass | Fail |
|---|---|---|---|
| 1 Health | 2 | 2 | 0 |
| 3 Geo | 11 | 11 | 0 |
| 4 Categories | 2 | 2 | 0 |
| 2 Auth & me | 29 | 29 | 0 |
| 5 Issues — write | 19 | 19 | 0 |
| 6 Issues — lifecycle | 19 | 19 | 0 |
| 7 Discovery | 18 | 18 | 0 |
| 8 Alerts | 12 | 12 | 0 |
| 9 Representatives | 18 | 18 | 0 |
| 10 Services & initiatives | 15 | 15 | 0 |
| 11 Staff — moderation | 18 | 18 | 0 |
| 11 Staff — alerts (two-person rule) | 24 | 24 | 0 |
| 11 Staff — representative claims | 10 | 10 | 0 |
| 11 Staff — ward dashboard and representative scope | 13 | 13 | 0 |
| 11 Staff — representative messages | 9 | 9 | 0 |
| 11 Staff — users and roles | 20 | 20 | 0 |
| 11 Staff — categories, settings, election mode, exports | 13 | 13 | 0 |
| 11 Staff — representatives roster | 15 | 15 | 0 |
| 11 Staff — services | 9 | 9 | 0 |
| 5.5 Role matrix — visitor | 14 | 14 | 0 |
| 5.5 Role matrix — citizen on every staff endpoint | 2 | 2 | 0 |
| Audit file and API log content | 7 | 7 | 0 |
| 4 Categories — public read limit (runs last) | 2 | 2 | 0 |
| Cleanup (sweep data only) | 1 | 1 | 0 |
| Error-code sweep | 1 | 1 | 0 |
| Env-var sweep | 2 | 2 | 0 |

## Role matrix (§5.5) — one account per role

| Rule | Result | Checks (see full output) |
|---|---|---|
| Visitor browses feed, map, issue detail, alerts, services, ward directory, initiatives | PASS | 7 × 200 |
| Visitor is sent to sign-in for report, Me too, follow, verify, message, RSVP, flag | PASS | 7 × 401 `AUTH_REQUIRED` |
| Visitor on every staff endpoint (18 GETs) | PASS | all 401 |
| Citizen cannot reach any `/staff/*` endpoint (18 GETs + alert create, moderation, rep messages) | PASS | all 403 `FORBIDDEN` |
| Moderator cannot give the second approval of a Warning | PASS | 403 `ALERT_SECOND_APPROVER_ADMIN`; same approver twice 409 `ALERT_ALREADY_APPROVED`; moderator publish of a Warning 403 |
| Moderator cannot decide rep claims, change roles, write categories/services/roster/election mode, export | PASS | 403 `FORBIDDEN` each |
| Representative limited to own wards | PASS | scope = ward 18 only; other ward's dashboard, comment and status change 403 `WARD_OUT_OF_SCOPE` |
| Representative never verifies / rejects / merges / hides | PASS | 403 `FORBIDDEN_ROLE` (verify), 403 `FORBIDDEN` (reject, merge, hide) |
| Admin (v1 email login) reaches every admin route | PASS after fix `2131b2c` | services, initiatives, roster, election mode, claims, users, categories, export, alerts |
| Every staff action → one audit line with actor, role, target, no bodies | PASS after fix `2131b2c` | 27 audited actions read back from `AUDIT_LOG_FILE`; every `staff_action` line has `actorId`, `role`, `action`, `targetId`; none of 11 free-text markers (notes, reasons, message/reply bodies, claim note, alert body) in the audit file or the API log |
| Deleted and suspended users refused | PASS | deleted: 401 `TOKEN_REVOKED` (app and staff routes); suspended: session 401 `TOKEN_REVOKED`, new sign-in 403 `ACCOUNT_SUSPENDED` |
| API log / audit file carry no test phone numbers or session tokens | PASS | |

Audited actions verified one line each: `issue_status_changed` (moderator), `flag_resolved`, `issue_hidden`,
`issue_unhidden`, `issue_rejected`, `alert_created`, `alert_submitted`, `alert_approved` (moderator, admin),
`alert_published`, `alert_retracted`, `rep_claim_decided`, `rep_issue_comment`, `rep_issue_status`,
`rep_message_replied`, `role_changed` (×2), `user_suspended`, `user_unsuspended`, `category_updated`,
`election_mode_set`, `rep_deactivated` (×2), `rep_created`, `rep_updated`, `initiative.created`, `service.updated`,
`service.deactivated`.

Observed behaviour worth recording: a retracted alert's public detail returns **200 with `status: "retracted"`**
(not 404), so the app can show "This alert was withdrawn".

## Error-code sweep

Generated from `ERROR_CODES` in `apps/api/src/lib/errors/index.ts` (81 codes). "Produced by" = the first sweep check
that received the code, else the Vitest file(s) asserting it by name. "App message" = the ARB key the app shows for it
(found in `apps/mobile/lib` next to the code; every key listed exists in both `app_en.arb` and `app_gu.arb`).

- Produced: **74** (sweep 56, Vitest 18). **Unreachable: 7** (findings below). Not produced: **0**.
- User-facing codes **without an app message (21)** — the app falls back to the generic "Something went wrong"
  (`errorInternal`) in English and Gujarati. Read-only finding; mobile not edited:
  - Staff console: `REP_DUPLICATE`, `REP_PERSONAL_NUMBER`, `ALERT_STATE_INVALID`, `ALERT_INCOMPLETE`,
    `ALERT_APPROVALS_MISSING`, `ALERT_ALREADY_APPROVED`, `ALERT_SECOND_APPROVER_ADMIN`, `ALERT_ALREADY_SUPERSEDED`,
    `INITIATIVE_NOT_STARTED`, `MERGE_INVALID`, `SELF_ROLE_CHANGE`, `SETTING_UNKNOWN`, `SELF_SUSPEND`,
    `USER_STATE_INVALID`, `ROLE_CHANGE_INVALID`, `NOT_VERIFIED`, `ALREADY_REPLIED`.
  - Citizen app: `IDEMPOTENCY_KEY_REUSED` (report retry with a reused id), `SIGNED_IN_USE_ME` (device subscriptions
    while signed in — app should never hit it), `CCRS_NOT_LINKED` ("AMC closed it" before linking), `WARD_REQUIRED`
    (feed without a ward — app always sends one).
- Handled indirectly (code mapped to a feature state, which shows its own ARB text; 9): `INTERNAL_ERROR`,
  `REP_NO_CONTACT`, `MESSAGE_LANGUAGE`, `INITIATIVE_NOT_OPEN`, `INITIATIVE_FULL`, `INITIATIVE_STARTED`,
  `INVALID_TRANSITION`, `ISSUE_STATE_INVALID`, `FLAG_QUOTA`.
- Unreachable in the assembled app (append-only `ERROR_CODES`, so not removed; candidates for clean-up):
  `INVITE_CODE_INVALID`, `INVITE_CODE_TAKEN` (v1 invite codes; routes 410), `VERIFY_TOKEN_INVALID`,
  `VERIFY_TOKEN_REVOKED` (v1 `/verify`, 410; `requireVerifyToken`/`verify.service` not imported by any router),
  `COMPLAINT_EXCLUDED`, `COMPLAINT_ANONYMIZED` (`reminders.service` not imported by any router), `OUT_OF_WARD`
  (`lifecycle.service` check is shadowed by the TASK-11 hook's `WARD_OUT_OF_SCOPE`; the app maps both to
  `issueActionsForbidden`).

| # | Code | HTTP | Produced by | App message (ARB key, en + gu) |
|---|---|---|---|---|
| 1 | `VALIDATION_FAILED` | 400 | sweep: GET /wards/{not-a-uuid} → 400 VALIDATION_FAILED | errorValidationFailed, linkCcrsRequired, staffLoginFailed |
| 2 | `INVITE_CODE_INVALID` | 404 | unreachable — only in modules/public/invite.service.ts, which no router imports (/invite-codes/validate is 410) | n/a — v1 invite codes (retired, D11) |
| 3 | `INVITE_CODE_TAKEN` | 409 | unreachable — only in v1 invite-code create (reference.service); the admin write routes are 410 | n/a — v1 invite codes (retired, D11) |
| 4 | `CATEGORY_INACTIVE` | 422 | sweep: POST /issues unknown category → 422 CATEGORY_INACTIVE | errorCategoryInactive |
| 5 | `PHOTO_UNUSABLE` | 422 | sweep: POST /issues someone else's photo → 422 PHOTO_UNUSABLE | errorPhotoUnusable, reportFlowPhotoExpired |
| 6 | `PHOTO_TOO_LARGE` | 413 | sweep: POST /photos over PHOTO_MAX_UPLOAD_BYTES → 413 PHOTO_TOO_LARGE | errorPhotoTooLarge |
| 7 | `PHOTO_TYPE_UNSUPPORTED` | 415 | sweep: POST /photos not a JPEG → 415 PHOTO_TYPE_UNSUPPORTED | errorPhotoTypeUnsupported |
| 8 | `PHOTO_DELETED` | 410 | vitest: retention.test.ts | errorPhotoDeleted |
| 9 | `VERIFY_TOKEN_INVALID` | 401 | unreachable — lib/verifyToken is used only by requireVerifyToken/verify.service, neither mounted (/verify is 410) | n/a — v1 verify links (retired, D11) |
| 10 | `VERIFY_TOKEN_REVOKED` | 410 | unreachable — same as VERIFY_TOKEN_INVALID | n/a — v1 verify links (retired, D11) |
| 11 | `INVALID_CREDENTIALS` | 401 | vitest: admin-auth.test.ts | errorInvalidCredentials, staffLoginFailed |
| 12 | `ADMIN_DISABLED` | 403 | vitest: admin-auth.test.ts | errorAdminDisabled, staffLoginSuspended |
| 13 | `TOKEN_EXPIRED` | 401 | sweep: GET /me expired session token → 401 TOKEN_EXPIRED | errorSessionEnded |
| 14 | `TOKEN_REVOKED` | 401 | sweep: GET /me malformed bearer → 401 TOKEN_REVOKED | errorSessionEnded |
| 15 | `COMPLAINT_EXCLUDED` | 409 | unreachable — only in modules/reminders/reminders.service.ts, which no router imports | n/a — v1 complaints (retired, D11) |
| 16 | `COMPLAINT_ANONYMIZED` | 409 | unreachable — same as COMPLAINT_EXCLUDED | n/a — v1 complaints (retired, D11) |
| 17 | `NOT_FOUND` | 404 | sweep: GET /wards/{unknown id} → 404 NOT_FOUND | errorNotFound, alertsDetailNotAvailable, discoveryNotAvailable, initiativesNotFound, servicesNotListed, repNotFound |
| 18 | `RATE_LIMITED` | 429 | sweep: issue 11 in a day → 429 RATE_LIMITED | errorRateLimited, reportFlowQuota |
| 19 | `INTERNAL_ERROR` | 500 | vitest: error-scrub.test.ts | handled in apps/mobile/lib/core/api/app_error.dart (no direct ARB key found) |
| 20 | `SERVICE_UNAVAILABLE` | 503 | sweep: GET /health with the database unreachable → 503 SERVICE_UNAVAILABLE | errorServiceUnavailable |
| 21 | `ENDPOINT_RETIRED` | 410 | vitest: categories.test.ts, status.test.ts +1 | n/a — returned to v1 app builds only |
| 22 | `OUTSIDE_SERVICE_AREA` | 422 | sweep: GET /geo/locate far outside → 422 OUTSIDE_SERVICE_AREA | reportFlowOutsideArea |
| 23 | `AUTH_REQUIRED` | 401 | sweep: GET /me without token → 401 AUTH_REQUIRED | authReasonGeneric |
| 24 | `FIREBASE_TOKEN_INVALID` | 401 | sweep: POST /auth/firebase garbage token → 401 FIREBASE_TOKEN_INVALID | authErrorTokenInvalid |
| 25 | `AGE_CONFIRMATION_REQUIRED` | 403 | sweep: POST /auth/firebase without age confirmation → 403 AGE_CONFIRMATION_REQUIRED | authErrorAgeRequired |
| 26 | `CONSENT_REQUIRED` | 422 | sweep: POST /auth/firebase without core consent → 422 CONSENT_REQUIRED | authErrorConsentRequired |
| 27 | `CORE_CONSENT_REQUIRED` | 409 | sweep: POST /me/consents withdraw core → 409 CORE_CONSENT_REQUIRED | authErrorCoreConsent |
| 28 | `ACCOUNT_SUSPENDED` | 403 | sweep: suspended user signs in → 403 ACCOUNT_SUSPENDED | authErrorSuspended, reportErrorSuspended |
| 29 | `FORBIDDEN` | 403 | sweep: escalation by a non-follower → 403 FORBIDDEN | authErrorForbidden, issueActionsForbidden |
| 30 | `WARD_NOT_FOUND` | 422 | sweep: PATCH /me unknown ward → 422 WARD_NOT_FOUND | authErrorWardNotFound |
| 31 | `FIREBASE_UNAVAILABLE` | 503 | vitest: auth.test.ts | authUnavailable |
| 32 | `REP_NO_CONTACT` | 422 | vitest: relay.test.ts | handled in apps/mobile/lib/features/ward/application/ward_providers.dart (no direct ARB key found) |
| 33 | `MESSAGE_LANGUAGE` | 422 | sweep: profanity in a relay message → 422 MESSAGE_LANGUAGE | handled in apps/mobile/lib/features/ward/application/ward_providers.dart (no direct ARB key found) |
| 34 | `REP_DUPLICATE` | 409 | sweep: same name, role and term again → 409 REP_DUPLICATE | MISSING — falls back to the generic error message |
| 35 | `REP_PERSONAL_NUMBER` | 400 | sweep: roster entry with a mobile number → 400 REP_PERSONAL_NUMBER | MISSING — falls back to the generic error message |
| 36 | `ELECTION_MODE_FROZEN` | 409 | vitest: scorecard.test.ts, t11-actions.test.ts +1 | wardDashErrorFrozen |
| 37 | `WARD_CONFIRMATION_REQUIRED` | 422 | sweep: POST /issues just outside, unconfirmed → 422 WARD_CONFIRMATION_REQUIRED | reportErrorWardConfirmation |
| 38 | `IDEMPOTENCY_KEY_REUSED` | 409 | sweep: POST /issues clientSubmissionId reused by another user → 409 IDEMPOTENCY_KEY_REUSED | MISSING — falls back to the generic error message |
| 39 | `OWN_ISSUE` | 409 | sweep: me-too on own issue → 409 OWN_ISSUE | reportErrorOwnIssue |
| 40 | `ISSUE_NOT_OPEN` | 409 | vitest: engage.test.ts, escalation-events.test.ts | reportErrorNotOpen |
| 41 | `CCRS_ALREADY_LINKED` | 409 | sweep: link a different CCRS number → 409 CCRS_ALREADY_LINKED | linkCcrsConflict |
| 42 | `ALERT_STATE_INVALID` | 409 | sweep: submit an alert that is already pending → 409 ALERT_STATE_INVALID | MISSING — falls back to the generic error message |
| 43 | `ALERT_INCOMPLETE` | 422 | vitest: staff-flow.test.ts | MISSING — falls back to the generic error message |
| 44 | `ALERT_APPROVALS_MISSING` | 409 | sweep: moderator publishes before the second approval → 409 ALERT_APPROVALS_MISSING | MISSING — falls back to the generic error message |
| 45 | `ALERT_ALREADY_APPROVED` | 409 | sweep: same moderator approves again → 409 ALERT_ALREADY_APPROVED | MISSING — falls back to the generic error message |
| 46 | `ALERT_SECOND_APPROVER_ADMIN` | 403 | sweep: moderator gives the second approval → 403 ALERT_SECOND_APPROVER_ADMIN | MISSING — falls back to the generic error message |
| 47 | `ALERT_ALREADY_SUPERSEDED` | 409 | vitest: lifecycle.test.ts | MISSING — falls back to the generic error message |
| 48 | `SIGNED_IN_USE_ME` | 409 | sweep: signed-in user on the device subscriptions endpoint → 409 SIGNED_IN_USE_ME | MISSING — falls back to the generic error message |
| 49 | `INITIATIVE_NOT_OPEN` | 409 | sweep: RSVP to a cancelled drive → 409 INITIATIVE_NOT_OPEN | handled in apps/mobile/lib/features/initiatives/application/initiatives_providers.dart (no direct ARB key found) |
| 50 | `INITIATIVE_FULL` | 409 | sweep: RSVP to a full drive → 409 INITIATIVE_FULL | handled in apps/mobile/lib/features/initiatives/application/initiatives_providers.dart (no direct ARB key found) |
| 51 | `INITIATIVE_STARTED` | 409 | vitest: t14-error-codes.test.ts | handled in apps/mobile/lib/features/initiatives/application/initiatives_providers.dart (no direct ARB key found) |
| 52 | `INITIATIVE_NOT_STARTED` | 409 | sweep: admin marks attendance before start → 409 INITIATIVE_NOT_STARTED | MISSING — falls back to the generic error message |
| 53 | `INVALID_TRANSITION` | 409 | sweep: disallowed transition (acknowledged → acknowledged) → 409 INVALID_TRANSITION | handled in apps/mobile/lib/features/staff/shared/staff_widgets.dart (no direct ARB key found) |
| 54 | `SLUG_TAKEN` | 409 | sweep: same slug again → 409 SLUG_TAKEN | staffContentErrorSlugTaken |
| 55 | `STALE_STATUS` | 409 | sweep: stale expectedStatus → 409 STALE_STATUS | issueActionsStale |
| 56 | `FORBIDDEN_ROLE` | 403 | sweep: citizen (not reporter) changes status → 403 FORBIDDEN_ROLE | issueActionsForbidden |
| 57 | `OUT_OF_WARD` | 403 | unreachable — superseded: the TASK-11 pre-transition hook returns WARD_OUT_OF_SCOPE before lifecycle.service can throw it | issueActionsForbidden |
| 58 | `VERIFY_NOT_OPEN` | 409 | vitest: verification.test.ts | issueActionsVerifyClosed |
| 59 | `ALREADY_ANSWERED_TODAY` | 409 | sweep: second verification answer | issueActionsVerifyAlready |
| 60 | `TOO_FAR_FROM_ISSUE` | 422 | sweep: verify more than 100 m away → 422 TOO_FAR_FROM_ISSUE | issueActionsVerifyTooFar |
| 61 | `LOCATION_TOO_INACCURATE` | 422 | sweep: verify with 80 m accuracy → 422 LOCATION_TOO_INACCURATE | issueActionsVerifyInaccurate |
| 62 | `CCRS_NOT_LINKED` | 409 | sweep: POST /issues/{id}/ccrs/closed before linking → 409 CCRS_NOT_LINKED | MISSING — falls back to the generic error message |
| 63 | `WARD_OUT_OF_SCOPE` | 403 | sweep: representative dashboard for another ward → 403 WARD_OUT_OF_SCOPE | wardDashErrorOutOfScope |
| 64 | `ISSUE_STATE_INVALID` | 409 | sweep: reject it again → 409 ISSUE_STATE_INVALID | handled in apps/mobile/lib/features/staff/shared/staff_widgets.dart (no direct ARB key found) |
| 65 | `MERGE_INVALID` | 422 | sweep: merge an issue into itself → 422 MERGE_INVALID | MISSING — falls back to the generic error message |
| 66 | `SELF_ROLE_CHANGE` | 409 | vitest: users-flags.test.ts | MISSING — falls back to the generic error message |
| 67 | `SETTING_UNKNOWN` | 400 | sweep: admin PUT /staff/settings/{unknown} → 400 SETTING_UNKNOWN | MISSING — falls back to the generic error message |
| 68 | `EXPORT_TOO_LARGE` | 413 | vitest: t14-error-codes.test.ts | staffExportTooMany |
| 69 | `FLAG_QUOTA` | 429 | vitest: t14-error-codes.test.ts | handled in apps/mobile/lib/features/staff/flags/flag_content_sheet.dart (no direct ARB key found) |
| 70 | `SELF_SUSPEND` | 409 | sweep: moderator suspends self → 409 SELF_SUSPEND | MISSING — falls back to the generic error message |
| 71 | `USER_STATE_INVALID` | 409 | sweep: suspend again → 409 USER_STATE_INVALID | MISSING — falls back to the generic error message |
| 72 | `ROLE_CHANGE_INVALID` | 422 | sweep: admin changes a representative's role → 422 ROLE_CHANGE_INVALID | MISSING — falls back to the generic error message |
| 73 | `WARD_REQUIRED` | 400 | sweep: GET /feed without ward (visitor) → 400 WARD_REQUIRED | MISSING — falls back to the generic error message |
| 74 | `CLAIM_ALREADY_PENDING` | 409 | sweep: second claim on the same profile while one is pending → 409 CLAIM_ALREADY_PENDING | repClaimSeeMine, repClaimErrorPending |
| 75 | `REPRESENTATIVE_ALREADY_VERIFIED` | 409 | sweep: claim a verified profile → 409 REPRESENTATIVE_ALREADY_VERIFIED | repClaimErrorVerified |
| 76 | `REPRESENTATIVE_TERM_ENDED` | 422 | vitest: t11-claims.test.ts | repClaimErrorTermEnded |
| 77 | `ROLE_CONFLICT` | 409 | vitest: t11-claims.test.ts | repClaimErrorRoleConflict |
| 78 | `CLAIM_NOT_PENDING` | 409 | sweep: decide it again → 409 CLAIM_NOT_PENDING | repClaimConflict |
| 79 | `NOT_VERIFIED` | 409 | sweep: revoke verification of an unverified profile → 409 NOT_VERIFIED | MISSING — falls back to the generic error message |
| 80 | `ALREADY_REPLIED` | 409 | sweep: second reply → 409 ALREADY_REPLIED | MISSING — falls back to the generic error message |
| 81 | `BAD_SIGNATURE` | 401 | sweep: webhook without signature → 401 BAD_SIGNATURE | n/a — mail webhook only (server to server) |

## Env-var sweep

Every variable declared in `apps/api/src/config/index.ts` (96) against `apps/api/.env.example`, and for each one whose
removal fails `parseConfig`, a **real startup** of `src/server.ts` with that variable removed from an otherwise valid
environment (in memory, never written to disk): it must exit non-zero printing `Config error: <NAME> …` (names and
problems only, never values). Result: all 96 listed (after `2131b2c`); all 19 required variables fail startup clearly;
the other 77 have defaults or are optional (cross-field rules such as `PHOTO_STORAGE_DIR` when
`STORAGE_DRIVER=local`, R2 settings for `cloudflare_r2`, `GOOGLE_APPLICATION_CREDENTIALS` for FCM are covered by
`test/ops/config.test.ts`).

| Variable | In .env.example | Required | Removing it at startup |
|---|---|---|---|
| `APP_ENV` | yes | yes | exit 1 — `Config error: APP_ENV Invalid option: expected one of "development"\|"production"` |
| `API_HOST` | yes | yes | exit 1 — `Config error: API_HOST Invalid input: expected string, received undefined` |
| `API_PORT` | yes | yes | exit 1 — `Config error: API_PORT Invalid input: expected number, received NaN` |
| `DATABASE_URL` | yes | yes | exit 1 — `Config error: DATABASE_URL Invalid input: expected string, received undefined` |
| `JWT_SECRET` | yes | yes | exit 1 — `Config error: JWT_SECRET Invalid input: expected string, received undefined` |
| `JWT_ISSUER` | yes | yes | exit 1 — `Config error: JWT_ISSUER Invalid input: expected string, received undefined` |
| `JWT_AUDIENCE` | yes | yes | exit 1 — `Config error: JWT_AUDIENCE Invalid input: expected string, received undefined` |
| `JWT_EXPIRES_IN` | yes | yes | exit 1 — `Config error: JWT_EXPIRES_IN Invalid input: expected string, received undefined` |
| `STORAGE_DRIVER` | yes | yes | exit 1 — `Config error: STORAGE_DRIVER Invalid option: expected one of "local"\|"cloudflare_r2"` |
| `PHOTO_STORAGE_DIR` | yes | yes | exit 1 — `Config error: PHOTO_STORAGE_DIR is required when STORAGE_DRIVER=local` |
| `R2_ACCOUNT_ID` | yes | no (default) | — |
| `R2_ACCESS_KEY_ID` | yes | no (default) | — |
| `R2_SECRET_ACCESS_KEY` | yes | no (default) | — |
| `R2_BUCKET` | yes | no (default) | — |
| `R2_ENDPOINT` | yes | no (default) | — |
| `DEPLOY_ENV` | yes | no (default) | — |
| `SENTRY_DSN` | yes | no (default) | — |
| `SENTRY_TRACES_SAMPLE_RATE` | yes | no (default) | — |
| `RETENTION_CLOSED_PHOTO_DAYS` | yes | no (default) | — |
| `RETENTION_NOTIFICATION_DAYS` | yes | no (default) | — |
| `RETENTION_LOG_DAYS` | yes | no (default) | — |
| `REOPEN_WINDOW_DAYS` | yes | no (default) | — |
| `PHOTO_MAX_UPLOAD_BYTES` | yes | yes | exit 1 — `Config error: PHOTO_MAX_UPLOAD_BYTES Invalid input: expected number, received NaN` |
| `PHOTO_MAX_EDGE_PX` | yes | yes | exit 1 — `Config error: PHOTO_MAX_EDGE_PX Invalid input: expected number, received NaN` |
| `UNATTACHED_PHOTO_TTL_HOURS` | yes | yes | exit 1 — `Config error: UNATTACHED_PHOTO_TTL_HOURS Invalid input: expected number, received NaN` |
| `REMINDER_INTERVAL_DAYS` | yes | yes | exit 1 — `Config error: REMINDER_INTERVAL_DAYS Invalid input: expected number, received NaN` |
| `VERIFY_LINK_BASE` | yes | yes | exit 1 — `Config error: VERIFY_LINK_BASE Invalid input: expected string, received undefined` |
| `VERIFY_DISTANCE_WARN_M` | yes | no (default) | — |
| `CONSENT_TEXT_VERSIONS` | yes | yes | exit 1 — `Config error: CONSENT_TEXT_VERSIONS Invalid input: expected string, received undefined` |
| `REMINDER_TEMPLATE_VERSION` | yes | yes | exit 1 — `Config error: REMINDER_TEMPLATE_VERSION Invalid input: expected "v1"` |
| `CORS_ORIGINS` | yes | no (default) | — |
| `TRUST_PROXY` | yes | yes | exit 1 — `Config error: TRUST_PROXY Invalid option: expected one of "true"\|"false"` |
| `LOG_LEVEL` | yes | yes | exit 1 — `Config error: LOG_LEVEL Invalid option: expected one of "fatal"\|"error"\|"warn"\|"info"\|"debug"\|"trace"` |
| `LOG_FILE_DIR` | yes | no (default) | — |
| `SEED_ADMIN_EMAIL` | yes | no (default) | — |
| `SEED_ADMIN_PASSWORD` | yes | no (default) | — |
| `GEO_NEAREST_MAX_M` | yes | no (default) | — |
| `FIREBASE_AUTH_MODE` | yes | no (default) | — |
| `FIREBASE_PROJECT_ID` | yes | no (default) | — |
| `FIREBASE_AUTH_EMULATOR_HOST` | yes | no (default) | — |
| `GOOGLE_APPLICATION_CREDENTIALS` | yes | no (default) | — |
| `USER_JWT_AUDIENCE` | yes | no (default) | — |
| `USER_JWT_EXPIRES_IN` | yes | no (default) | — |
| `PUSH_DRIVER` | yes | no (default) | — |
| `CONSENT_TEXT_VERSIONS_V2` | yes | no (default) | — |
| `GRIEVANCE_EMAIL` | yes | no (default) | — |
| `EMAIL_DRIVER` | yes | no (default) | — |
| `EMAIL_FILE_DIR` | yes | no (default) | — |
| `SES_REGION` | yes | no (default) | — |
| `SES_FROM` | yes | no (default) | — |
| `EMAIL_OPS_ADDRESS` | yes | no (default) | — |
| `PUBLIC_WEB_BASE_URL` | yes | no (default) | — |
| `RELAY_PER_REP_DAILY` | yes | no (default) | — |
| `RELAY_PER_USER_DAILY` | yes | no (default) | — |
| `SCORECARD_MIN_SAMPLE` | yes | no (default) | — |
| `DUPLICATE_RADIUS_M` | yes | no (default) | — |
| `DUPLICATE_WINDOW_DAYS` | yes | no (default) | — |
| `ISSUE_MAX_PHOTOS` | yes | no (default) | — |
| `QUOTA_ISSUES_PER_DAY` | yes | no (default) | — |
| `QUOTA_ME_TOO_PER_DAY` | yes | no (default) | — |
| `QUOTA_VERIFICATIONS_PER_DAY` | yes | no (default) | — |
| `QUOTA_MESSAGES_PER_REP_PER_DAY` | yes | no (default) | — |
| `QUOTA_PHOTOS_PER_DAY` | yes | no (default) | — |
| `AMC_PROBLEMS_URL` | yes | no (default) | — |
| `AMC_PROBLEMS_MIN_INTERVAL_HOURS` | yes | no (default) | — |
| `AMC_FETCH_CONTACT_EMAIL` | yes | no (default) | — |
| `JOBS_ENABLED` | yes | no (default) | — |
| `ALERT_MAX_VALIDITY_DAYS` | yes | no (default) | — |
| `QUIET_HOURS` | yes | no (default) | — |
| `APP_TIMEZONE` | yes | no (default) | — |
| `SACHET_ENABLED` | yes | no (default) | — |
| `SACHET_FEED_URL` | yes | no (default) | — |
| `SACHET_POLL_MINUTES` | yes | no (default) | — |
| `IMD_ENABLED` | yes | no (default) | — |
| `IMD_DISTRICT_WARNINGS_URL` | yes | no (default) | — |
| `VERIFY_RADIUS_M` | yes | no (default) | — |
| `VERIFY_MAX_ACCURACY_M` | yes | no (default) | — |
| `NOT_FIXED_THRESHOLD` | yes | no (default) | — |
| `CCRS_REOPEN_HOURS` | yes | no (default) | — |
| `CCRS_REMINDER_AFTER_HOURS` | yes | no (default) | — |
| `QUOTA_STATUS_CHANGES_PER_DAY` | yes | no (default) | — |
| `QUOTA_ESCALATIONS_PER_DAY` | yes | no (default) | — |
| `STAFF_WEB_ORIGINS` | yes | no (default) | — |
| `AUDIT_LOG_FILE` | yes | no (default) | — |
| `AUDIT_RETENTION_DAYS` | yes | no (default) | — |
| `EXPORT_MAX_ROWS` | yes | no (default) | — |
| `EXPORT_HMAC_SECRET` | yes | no (default) | — |
| `FEED_CACHE_SECONDS` | yes | no (default) | — |
| `MAP_CLUSTER_MAX_ZOOM` | yes | no (default) | — |
| `MAP_POINTS_MAX` | yes | no (default) | — |
| `ISSUES_PAGE_MAX` | yes | no (default) | — |
| `REP_CLAIM_MAX_PER_DAY` | yes | no (default) | — |
| `REP_EXPORT_MAX_PER_HOUR` | yes | no (default) | — |
| `MAIL_INBOUND_SECRET` | yes | no (default) | — |
| `MAIL_REPLY_DOMAIN` | yes | no (default) | — |
| `REP_DASHBOARD_HOTSPOT_CELL_M` | yes | no (default) | — |

## Assumptions

- ASSUMPTION: The brief's `PORT=4200` is the API's `API_PORT` (there is no `PORT` variable in `src/config`).
- ASSUMPTION: "503 with DB stopped" is exercised on a throwaway instance (port 4201) whose `DATABASE_URL` points at a
  closed port, because the shared dev database must not be stopped.
- ASSUMPTION: Codes only reachable from v1 code that no router mounts are reported as **unreachable** findings instead
  of failing the "every code produced" check; `ERROR_CODES` is append-only, so removal is left to the integrator.
- ASSUMPTION: "User-facing" = every code except the server-to-server webhook code and the v1-retired codes; the staff
  console counts as user-facing (it is the same app and uses the same ARB files).
- ASSUMPTION: The ARB key per code is found statically next to the code in `apps/mobile/lib` (`case 'CODE': … l10n.key`
  within the same case body); codes mapped to a feature enum are listed as "handled indirectly".
- ASSUMPTION: To exercise roster create/update/delete on the dev database (every ward already has 4 active
  corporators; dev constituencies are numbered 901+, outside the roster's 1–400 rule) the sweep deactivates sample
  corporator 18-D through the API and restores it in the database in a `finally`.
- ASSUMPTION: Verification 20/day 429 is covered by `test/lifecycle/verification.test.ts`, not the live sweep (it needs
  20 issues in the fixed state); issues 10/day 429 and relay 5/day 429 are exercised live.

## Full output (final run)

```text
api-sweep against http://127.0.0.1:4200/api/v1 at 2026-10-04T12:10:56.573Z

== 1 Health
PASS  GET /health → 200 status ok, db up — 200
PASS  GET /health with the database unreachable → 503 SERVICE_UNAVAILABLE — 503 SERVICE_UNAVAILABLE

== 3 Geo
PASS  GET /wards → 200 with 48 wards — 200 n=48
PASS  GET /wards/{id} → 200 ward 18 — 200
PASS  GET /wards/{unknown id} → 404 NOT_FOUND — 404 NOT_FOUND
PASS  GET /wards/{not-a-uuid} → 400 VALIDATION_FAILED — 400 VALIDATION_FAILED
PASS  GET /zones → 200 with zones — 200 n=7
PASS  GET /geo/locate inside ward 18 → match inside, confirm false — 200 inside
PASS  GET /geo/locate inside ward 15 → ward 15 — 200
PASS  GET /geo/locate just outside the polygons → nearest ward + confirm:true — 200 nearest 1574 m
PASS  GET /geo/locate far outside → 422 OUTSIDE_SERVICE_AREA — 422 OUTSIDE_SERVICE_AREA
PASS  GET /geo/locate bad coords → 400 VALIDATION_FAILED — 400 VALIDATION_FAILED
PASS  GET /geo/locate lat out of range → 400 VALIDATION_FAILED — 400 VALIDATION_FAILED

== 4 Categories
PASS  GET /categories → 200 with active categories — 200 n=14
PASS  categories carry slug, names in en+gu

== 2 Auth & me
PASS  POST /auth/firebase new citizen → 201 isNew — 201
PASS  sign-in response masks the phone
PASS  POST /auth/firebase returning citizen → 200 isNew false — 200
PASS  test accounts signed in (A, B, C, D, moderator, representative)
PASS  moderator account has role moderator — moderator
PASS  representative account has role representative — representative
PASS  v1 admin email login → 200 — 200
PASS  POST /auth/firebase garbage token → 401 FIREBASE_TOKEN_INVALID — 401 FIREBASE_TOKEN_INVALID
PASS  POST /auth/firebase expired Firebase token → 401 FIREBASE_TOKEN_INVALID — 401 FIREBASE_TOKEN_INVALID
   (waiting 62 s for the sign-in rate window)
PASS  POST /auth/firebase without age confirmation → 403 AGE_CONFIRMATION_REQUIRED — 403 AGE_CONFIRMATION_REQUIRED
PASS  POST /auth/firebase without core consent → 422 CONSENT_REQUIRED — 422 CONSENT_REQUIRED
PASS  under-18 attempt created no account
PASS  GET /me → 200 own profile — 200
PASS  GET /me without token → 401 AUTH_REQUIRED — 401 AUTH_REQUIRED
PASS  GET /me malformed bearer → 401 TOKEN_REVOKED — 401 TOKEN_REVOKED
PASS  GET /me expired session token → 401 TOKEN_EXPIRED — 401 TOKEN_EXPIRED
PASS  PATCH /me → 200 — 200
PASS  PATCH /me empty body → 400 VALIDATION_FAILED — 400 VALIDATION_FAILED
PASS  PATCH /me unknown ward → 422 WARD_NOT_FOUND — 422 WARD_NOT_FOUND
PASS  POST /me/consents grant → 200 — 200
PASS  POST /me/consents withdraw core → 409 CORE_CONSENT_REQUIRED — 409 CORE_CONSENT_REQUIRED
PASS  POST /devices → 2xx — 200
PASS  POST /devices bad body → 400 VALIDATION_FAILED — 400 VALIDATION_FAILED
PASS  GET /me/export → 200 JSON with own profile only — 200
PASS  POST /auth/logout → 204 — 204
PASS  revoked session → 401 TOKEN_REVOKED — 401 TOKEN_REVOKED
PASS  DELETE /me without confirm → 400 VALIDATION_FAILED — 400 VALIDATION_FAILED
PASS  DELETE /me → 204 — 204
PASS  deleted user → 401 TOKEN_REVOKED — 401 TOKEN_REVOKED

== 5 Issues — write
PASS  POST /photos without token → 401 AUTH_REQUIRED — 401 AUTH_REQUIRED
PASS  POST /photos → 201 photo id — 201
PASS  POST /photos over PHOTO_MAX_UPLOAD_BYTES → 413 PHOTO_TOO_LARGE — 413 PHOTO_TOO_LARGE
PASS  POST /photos not a JPEG → 415 PHOTO_TYPE_UNSUPPORTED — 415 PHOTO_TYPE_UNSUPPORTED
PASS  POST /photos bad purpose → 400 VALIDATION_FAILED — 400 VALIDATION_FAILED
PASS  POST /issues without token → 401 AUTH_REQUIRED — 401 AUTH_REQUIRED
PASS  POST /issues far outside the city → 422 OUTSIDE_SERVICE_AREA — 422 OUTSIDE_SERVICE_AREA
PASS  POST /issues just outside, unconfirmed → 422 WARD_CONFIRMATION_REQUIRED — 422 WARD_CONFIRMATION_REQUIRED
PASS  POST /issues unknown category → 422 CATEGORY_INACTIVE — 422 CATEGORY_INACTIVE
PASS  POST /issues someone else's photo → 422 PHOTO_UNUSABLE — 422 PHOTO_UNUSABLE
PASS  POST /issues → 201 reported in ward 18 — 201 reported
PASS  POST /issues same clientSubmissionId → 200 same issue (idempotent) — 200
PASS  POST /issues clientSubmissionId reused by another user → 409 IDEMPOTENCY_KEY_REUSED — 409 IDEMPOTENCY_KEY_REUSED
PASS  second issue by A → 201 — 201
PASS  GET /issues/nearby → 200 includes the new issue — 200 n=2
PASS  GET /issues/nearby missing category → 400 VALIDATION_FAILED — 400 VALIDATION_FAILED
PASS  10 issues in a day accepted — 10/10
PASS  issue 11 in a day → 429 RATE_LIMITED — 429 RATE_LIMITED
PASS  quota 429 names issues_per_day and sends Retry-After

== 6 Issues — lifecycle
PASS  GET /issues/{id}/events → 200 with the reported event — 200
PASS  GET /issues/{unknown}/events → 404 NOT_FOUND — 404 NOT_FOUND
PASS  citizen (not reporter) changes status → 403 FORBIDDEN_ROLE — 403 FORBIDDEN_ROLE
PASS  stale expectedStatus → 409 STALE_STATUS — 409 STALE_STATUS
PASS  moderator acknowledges → 200 acknowledged — 200
PASS  moderator status change → exactly one audit line (actor, role, target) — lines=1
PASS  disallowed transition (acknowledged → acknowledged) → 409 INVALID_TRANSITION — 409 INVALID_TRANSITION
PASS  moderator marks fixed → 200 marked_fixed — 200 
PASS  verify more than 100 m away → 422 TOO_FAR_FROM_ISSUE — 422 TOO_FAR_FROM_ISSUE
PASS  verify with 80 m accuracy → 422 LOCATION_TOO_INACCURATE — 422 LOCATION_TOO_INACCURATE
PASS  representative verifies → 403 FORBIDDEN_ROLE — 403 FORBIDDEN_ROLE
PASS  neighbour verifies within 100 m → 201 — 201 
PASS  reporter may answer on own issue (TASK-06 §5.6: reporter's answer counts) → 201 — 201 
PASS  second answer the same day → 409 (ALREADY_ANSWERED_TODAY or VERIFY_NOT_OPEN) — 409 ALREADY_ANSWERED_TODAY
PASS  POST /issues/{id}/escalations by reporter (follower) → 200 prepared message — 200 
PASS  escalation by a non-follower → 403 FORBIDDEN — 403 FORBIDDEN
PASS  POST /issues/{id}/ccrs/closed before linking → 409 CCRS_NOT_LINKED — 409 CCRS_NOT_LINKED
PASS  POST /issues/{id}/ccrs link → 200 — 200 
PASS  link a different CCRS number → 409 CCRS_ALREADY_LINKED — 409 CCRS_ALREADY_LINKED

== 7 Discovery
PASS  GET /issues?ward → 200 list — 200 n=17
PASS  public list carries no reporterId / phone
PASS  GET /issues bad cursor → 400 VALIDATION_FAILED — 400 VALIDATION_FAILED
PASS  GET /issues bad status filter → 400 VALIDATION_FAILED — 400 VALIDATION_FAILED
PASS  GET /issues/{id} → 200 detail without reporter identity — 200
PASS  GET /issues/{unknown} → 404 NOT_FOUND — 404 NOT_FOUND
PASS  POST /issues/{id}/me-too → 201 — 201
PASS  duplicate me-too → 200 idempotent, count unchanged — 200
PASS  me-too on own issue → 409 OWN_ISSUE — 409 OWN_ISSUE
PASS  DELETE /issues/{id}/me-too → 200 — 200
PASS  POST /issues/{id}/follow → 200 following — 200
PASS  DELETE /issues/{id}/follow → 200 not following — 200
PASS  GET /feed?ward → 200 — 200
PASS  GET /feed without ward (visitor) → 400 WARD_REQUIRED — 400 WARD_REQUIRED
PASS  GET /map/issues → 200 — 200
PASS  GET /map/issues bbox too large → 400 VALIDATION_FAILED — 400 VALIDATION_FAILED
PASS  POST /issues/{id}/flags → 201 — 201 
PASS  POST /issues/{id}/flags bad reason → 400 VALIDATION_FAILED — 400 VALIDATION_FAILED

== 8 Alerts
PASS  GET /alerts?wards → 200 list — 200
PASS  every alert item has source and validity
PASS  GET /alerts without wards → 400 VALIDATION_FAILED — 400 VALIDATION_FAILED
PASS  GET /alerts/{unknown} → 404 NOT_FOUND — 404 NOT_FOUND
PASS  GET /me/subscriptions → 200 — 200
PASS  PUT /me/subscriptions → 200 — 200 
PASS  PUT /me/subscriptions duplicate wards → 400 VALIDATION_FAILED — 400 VALIDATION_FAILED
PASS  GET /me/subscriptions without token → 401 AUTH_REQUIRED — 401 AUTH_REQUIRED
PASS  signed-in user on the device subscriptions endpoint → 409 SIGNED_IN_USE_ME — 409 SIGNED_IN_USE_ME
PASS  GET /me/notifications → 200 — 200
PASS  POST /me/notifications/read all → 200 unreadCount 0 — 200
PASS  GET /me/notifications without token → 401 AUTH_REQUIRED — 401 AUTH_REQUIRED

== 9 Representatives
PASS  GET /wards/{id}/representatives → 200 corporators — 200
PASS  directory exposes no user_id / claimant data
PASS  GET /representatives/{id} → 200 verified profile — 200
PASS  profile exposes only public contact fields
PASS  GET /representatives/{unknown} → 404 NOT_FOUND — 404 NOT_FOUND
PASS  GET /wards/{id}/scorecard → 200 — 200
PASS  relay without token → 401 AUTH_REQUIRED — 401 AUTH_REQUIRED
PASS  relay without the share consent → 403 CONSENT_REQUIRED — 403 CONSENT_REQUIRED
PASS  POST /representatives/{id}/messages → 202 queued — 202 
PASS  same clientMessageId → 200 idempotent — 200
PASS  5 messages to one representative in a day accepted — 202,202,202,202,202
PASS  6th message to the same representative → 429 RATE_LIMITED — 429 RATE_LIMITED
PASS  relay 429 sends Retry-After
PASS  profanity in a relay message → 422 MESSAGE_LANGUAGE — 422 MESSAGE_LANGUAGE
PASS  claim a verified profile → 409 REPRESENTATIVE_ALREADY_VERIFIED — 409 REPRESENTATIVE_ALREADY_VERIFIED
PASS  POST /representatives/{id}/claims → 201 pending — 201 
PASS  second claim on the same profile while one is pending → 409 CLAIM_ALREADY_PENDING — 409 CLAIM_ALREADY_PENDING
PASS  GET /me/rep-claims → 200 with the claim — 200

== 10 Services & initiatives
PASS  GET /services → 200 list — 200 n=17
PASS  GET /services/{slug} → 200 — 200
PASS  GET /services/{unknown slug} → 404 NOT_FOUND — 404 NOT_FOUND
PASS  GET /initiatives → 200 — 200
PASS  admin (v1 login) POST /staff/initiatives → 201 — 201 
PASS  initiative.created → one audit line (actor, role admin, target) — lines=1
PASS  GET /initiatives/{unknown} → 404 NOT_FOUND — 404 NOT_FOUND
PASS  POST /initiatives/{id}/rsvp → 2xx going — 200 
PASS  RSVP to a full drive → 409 INITIATIVE_FULL — 409 INITIATIVE_FULL
PASS  RSVP without token → 401 AUTH_REQUIRED — 401 AUTH_REQUIRED
PASS  DELETE /initiatives/{id}/rsvp → 2xx — 200
PASS  admin marks attendance before start → 409 INITIATIVE_NOT_STARTED — 409 INITIATIVE_NOT_STARTED
PASS  admin cancels the sweep drive → 200 — 200
PASS  cancelled → published → 409 INVALID_TRANSITION — 409 INVALID_TRANSITION
PASS  RSVP to a cancelled drive → 409 INITIATIVE_NOT_OPEN — 409 INITIATIVE_NOT_OPEN

== 11 Staff — moderation
PASS  moderator GET /staff/moderation → 200 — 200
PASS  citizen GET /staff/moderation → 403 FORBIDDEN — 403 FORBIDDEN
PASS  representative GET /staff/moderation → 403 FORBIDDEN — 403 FORBIDDEN
PASS  visitor GET /staff/moderation → 401 AUTH_REQUIRED — 401 AUTH_REQUIRED
PASS  moderator GET /staff/issues/{id} → 200 — 200
PASS  moderator resolves a flag → 200 — 200
PASS    ↳ one audit line flag_resolved (actor, role moderator, target) — lines=1 role=moderator
PASS  moderator hides an issue → 200 — 200
PASS    ↳ one audit line issue_hidden (actor, role moderator, target) — lines=1 role=moderator
PASS  moderator unhides it → 200 — 200
PASS    ↳ one audit line issue_unhidden (actor, role moderator, target) — lines=1 role=moderator
PASS  moderator rejects an issue → 200 — 200
PASS    ↳ one audit line issue_rejected (actor, role moderator, target) — lines=1 role=moderator
PASS  reject it again → 409 ISSUE_STATE_INVALID — 409 ISSUE_STATE_INVALID
PASS  merge an issue into itself → 422 MERGE_INVALID — 422 MERGE_INVALID
PASS  representative rejects an issue → 403 FORBIDDEN — 403 FORBIDDEN
PASS  representative merges → 403 FORBIDDEN — 403 FORBIDDEN
PASS  representative hides → 403 FORBIDDEN — 403 FORBIDDEN

== 11 Staff — alerts (two-person rule)
PASS  citizen POST /staff/alerts → 403 FORBIDDEN — 403 FORBIDDEN
PASS  representative POST /staff/alerts → 403 FORBIDDEN — 403 FORBIDDEN
PASS  moderator creates a Warning draft → 201 — 201
PASS    ↳ one audit line alert_created (actor, role moderator, target) — lines=1
PASS  moderator submits → 200 — 200
PASS    ↳ one audit line alert_submitted (actor, role moderator, target) — lines=1 role=moderator
PASS  moderator gives the first approval → 200 — 200
PASS    ↳ one audit line alert_approved (actor, role moderator, target) — lines=1 role=moderator
PASS  same moderator approves again → 409 ALERT_ALREADY_APPROVED — 409 ALERT_ALREADY_APPROVED
PASS  moderator publishes before the second approval → 409 ALERT_APPROVALS_MISSING — 409 ALERT_APPROVALS_MISSING
PASS  admin gives the second approval → 200 — 200
PASS    ↳ one audit line alert_approved (actor, role admin, target) — lines=1 role=admin
PASS  moderator publishes a Warning → 403 FORBIDDEN — 403 FORBIDDEN
PASS  admin publishes → 200 — 200
PASS    ↳ one audit line alert_published (actor, role admin, target) — lines=1 role=admin
PASS  GET /alerts/{id} → 200 with source, validity — 200
PASS  published Warning lists two different approvers (staff view)
PASS  admin retracts → 200 — 200
PASS    ↳ one audit line alert_retracted (actor, role admin, target) — lines=1 role=admin
PASS  retracted alert detail: public read shows it as retracted or gone — 200 retracted
PASS  admin gives the first approval on a second Warning → 200 — 200
PASS  moderator gives the second approval → 403 ALERT_SECOND_APPROVER_ADMIN — 403 ALERT_SECOND_APPROVER_ADMIN
PASS  same admin gives the second approval → 409 ALERT_ALREADY_APPROVED — 409 ALERT_ALREADY_APPROVED
PASS  submit an alert that is already pending → 409 ALERT_STATE_INVALID — 409 ALERT_STATE_INVALID

== 11 Staff — representative claims
PASS  moderator GET /staff/rep-claims → 200 — 200
PASS  claim evidence without token → 401 AUTH_REQUIRED — 401 AUTH_REQUIRED
PASS  claim evidence as moderator → 403 FORBIDDEN — 403 FORBIDDEN
PASS  claim evidence as representative → 403 FORBIDDEN — 403 FORBIDDEN
PASS  claim evidence as admin → 200 image, Cache-Control no-store — 200 no-store
PASS  moderator decides a claim → 403 FORBIDDEN — 403 FORBIDDEN
PASS  admin rejects the claim → 200 — 200
PASS    ↳ one audit line rep_claim_decided (actor, role admin, target) — lines=1 role=admin
PASS  revoke verification of an unverified profile → 409 NOT_VERIFIED — 409 NOT_VERIFIED
PASS  decide it again → 409 CLAIM_NOT_PENDING — 409 CLAIM_NOT_PENDING

== 11 Staff — ward dashboard and representative scope
PASS  representative GET /staff/ward/scope → 200, only ward 18 — 200 n=1
PASS  representative GET /staff/ward-dashboard own ward → 200 — 200
PASS  representative dashboard for another ward → 403 WARD_OUT_OF_SCOPE — 403 WARD_OUT_OF_SCOPE
PASS  ward dashboard export → 200 CSV without phone digits — 200
PASS  representative GET /staff/ward/issues own ward → 200 — 200
PASS  moderator dashboard for any ward → 200 — 200
PASS  representative comments on an own-ward issue → 201 — 201
PASS    ↳ one audit line rep_issue_comment (actor, role representative, target) — lines=1 role=representative
PASS  issue in ward 15 created for scope checks — 201
PASS  representative comments outside own wards → 403 WARD_OUT_OF_SCOPE — 403 WARD_OUT_OF_SCOPE
PASS  representative status change outside own wards → 403 WARD_OUT_OF_SCOPE — 403 WARD_OUT_OF_SCOPE
PASS  representative acknowledges an own-ward issue (sent) → 200 — 200
PASS    ↳ one audit line rep_issue_status (actor, role representative, target) — lines=1 role=representative

== 11 Staff — representative messages
PASS  citizen messages the verified representative → 202 — 202 
PASS  representative GET /staff/rep-messages → 200 with the message — 200
PASS  rep inbox shows no citizen phone (no opt-in)
PASS  moderator GET /staff/rep-messages → 403 FORBIDDEN — 403 FORBIDDEN
PASS  representative replies → 200 — 200
PASS    ↳ one audit line rep_message_replied (actor, role representative, target) — lines=1 role=representative
PASS  second reply → 409 ALREADY_REPLIED — 409 ALREADY_REPLIED
PASS  citizen GET /me/messages → 200 sees the reply — 200
PASS  webhook without signature → 401 BAD_SIGNATURE — 401 BAD_SIGNATURE

== 11 Staff — users and roles
PASS  moderator changes a role → 403 FORBIDDEN — 403 FORBIDDEN
PASS  admin GET /staff/users → 200 with masked phones only — 200
PASS  admin makes citizen C a moderator → 200 — 200
PASS    ↳ one audit line role_changed (actor, role admin, target) — lines=1 role=admin
PASS  admin returns C to citizen → 200 — 200
PASS    ↳ one audit line role_changed (actor, role admin, target) — lines=1 role=admin
PASS  admin changes a representative's role → 422 ROLE_CHANGE_INVALID — 422 ROLE_CHANGE_INVALID
PASS  moderator suspends C → 200 — 200
PASS    ↳ one audit line user_suspended (actor, role moderator, target) — lines=1 role=moderator
PASS  suspended user's session refused (§5.5: 401/403) — 401 TOKEN_REVOKED
PASS  suspended user signs in → 403 ACCOUNT_SUSPENDED — 403 ACCOUNT_SUSPENDED
PASS  suspend again → 409 USER_STATE_INVALID — 409 USER_STATE_INVALID
PASS  moderator suspends self → 409 SELF_SUSPEND — 409 SELF_SUSPEND
PASS  moderator unsuspends C → 200 — 200
PASS    ↳ one audit line user_unsuspended (actor, role moderator, target) — lines=1 role=moderator
PASS  deleted user on a staff endpoint → 401 TOKEN_REVOKED — 401 TOKEN_REVOKED
PASS  moderator GET /staff/me → 200 role moderator — 200 moderator
PASS  representative GET /staff/me → 200 role representative — 200 representative
PASS  admin GET /staff/me → 200 role admin — 200 admin
PASS  citizen GET /staff/me → 403 FORBIDDEN — 403 FORBIDDEN

== 11 Staff — categories, settings, election mode, exports
PASS  moderator GET /staff/categories → 200 — 200
PASS  moderator PATCH /staff/categories → 403 FORBIDDEN — 403 FORBIDDEN
PASS  admin PATCH /staff/categories/{id} (same sort order) → 200 — 200
PASS    ↳ one audit line category_updated (actor, role admin, target) — lines=1 role=admin
PASS  moderator GET /staff/settings → 200 — 200
PASS  admin PUT /staff/settings/{unknown} → 400 SETTING_UNKNOWN — 400 SETTING_UNKNOWN
PASS  admin (v1 login) GET /staff/settings/election-mode → 200 — 200 
PASS  moderator GET /staff/settings/election-mode → 200 — 200
PASS  moderator PUT election mode → 403 FORBIDDEN — 403 FORBIDDEN
PASS  admin PUT election mode (unchanged value) → 200 — 200
PASS    ↳ one audit line election_mode_set (actor, role admin, target) — lines=1 role=admin
PASS  moderator GET /staff/export → 403 FORBIDDEN — 403 FORBIDDEN
PASS  admin GET /staff/export → 200 CSV without phone — 200

== 11 Staff — representatives roster
PASS  moderator GET /staff/representatives → 200 — 200
PASS  admin (v1 login) GET /staff/representatives → 200 — 200 
PASS  moderator POST /staff/representatives → 403 FORBIDDEN — 403 FORBIDDEN
PASS  roster entry with a mobile number → 400 REP_PERSONAL_NUMBER — 400 REP_PERSONAL_NUMBER
PASS  fifth active corporator in a ward → 400 VALIDATION_FAILED (seat cap) — 400
PASS  admin DELETE /staff/representatives/{sample 18-D} → 200 deactivated — 200
PASS    ↳ one audit line rep_deactivated (actor, role admin, target) — lines=1 role=admin
PASS  admin POST /staff/representatives → 201 — 201 
PASS    ↳ one audit line rep_created (actor, role admin, target) — lines=1
PASS  admin PATCH /staff/representatives/{id} → 200 — 200
PASS    ↳ one audit line rep_updated (actor, role admin, target) — lines=1 role=admin
PASS  admin DELETE /staff/representatives/{id} → 200 deactivated — 200
PASS    ↳ one audit line rep_deactivated (actor, role admin, target) — lines=1 role=admin
PASS  same name, role and term again → 409 REP_DUPLICATE — 409 REP_DUPLICATE
PASS  sample corporator 18-D restored (active)

== 11 Staff — services
PASS  moderator GET /staff/services → 200 (read-only access) — 200
PASS  admin (v1 login) GET /staff/services → 200 — 200 
PASS  moderator POST /staff/services → 403 FORBIDDEN — 403 FORBIDDEN
PASS  admin POST /staff/services → 201 — 201 
PASS  same slug again → 409 SLUG_TAKEN — 409 SLUG_TAKEN
PASS  admin PATCH /staff/services/{id} → 200 — 200
PASS    ↳ one audit line service.updated (actor, role admin, target) — lines=1 role=admin
PASS  admin DELETE /staff/services/{id} → 200 deactivated — 204
PASS    ↳ one audit line service.deactivated (actor, role admin, target) — lines=1 role=admin

== 5.5 Role matrix — visitor
PASS  visitor can browse feed → 200 — 200
PASS  visitor can browse map → 200 — 200
PASS  visitor can browse issue detail → 200 — 200
PASS  visitor can browse alerts → 200 — 200
PASS  visitor can browse services → 200 — 200
PASS  visitor can browse ward directory → 200 — 200
PASS  visitor can browse initiatives → 200 — 200
PASS  visitor report → 401 AUTH_REQUIRED (sent to sign-in) — 401 AUTH_REQUIRED
PASS  visitor Me too → 401 AUTH_REQUIRED (sent to sign-in) — 401 AUTH_REQUIRED
PASS  visitor follow → 401 AUTH_REQUIRED (sent to sign-in) — 401 AUTH_REQUIRED
PASS  visitor verify → 401 AUTH_REQUIRED (sent to sign-in) — 401 AUTH_REQUIRED
PASS  visitor message → 401 AUTH_REQUIRED (sent to sign-in) — 401 AUTH_REQUIRED
PASS  visitor RSVP → 401 AUTH_REQUIRED (sent to sign-in) — 401 AUTH_REQUIRED
PASS  visitor flag → 401 AUTH_REQUIRED (sent to sign-in) — 401 AUTH_REQUIRED

== 5.5 Role matrix — citizen on every staff endpoint
PASS  citizen gets 403 on all 18 staff endpoints
PASS  visitor gets 401 on all 18 staff endpoints

== Audit file and API log content
PASS  audit file exists and has lines — 687 lines
PASS  every staff audit line has actorId, role, action, targetId
PASS  audit file contains no request bodies, notes, reasons or messages
PASS  API log file present — 1 file(s)
PASS  API log contains no request bodies, notes, reasons or messages
PASS  API log and audit file contain no test phone numbers — 0 found
PASS  API log and audit file contain no session tokens — 0 found

== 4 Categories — public read limit (runs last)
PASS  GET /categories → 429 RATE_LIMITED within 121 requests/min — first 429 at request 121
PASS  429 carries Retry-After

== Cleanup (sweep data only)
PASS  cleanup erased every sweep citizen (DELETE /me) — 4/4
   hidden 13 sweep issue(s); erased 4 sweep account(s)

== Error-code sweep
VALIDATION_FAILED              400  produced: sweep: GET /wards/{not-a-uuid} → 400 VALIDATION_FAILED  |  app: errorValidationFailed, linkCcrsRequired, staffLoginFailed
INVITE_CODE_INVALID            404  produced: unreachable — only in modules/public/invite.service.ts, which no router imports (/invite-codes/validate is 410)  |  app: n/a — v1 invite codes (retired, D11)
INVITE_CODE_TAKEN              409  produced: unreachable — only in v1 invite-code create (reference.service); the admin write routes are 410  |  app: n/a — v1 invite codes (retired, D11)
CATEGORY_INACTIVE              422  produced: sweep: POST /issues unknown category → 422 CATEGORY_INACTIVE  |  app: errorCategoryInactive
PHOTO_UNUSABLE                 422  produced: sweep: POST /issues someone else's photo → 422 PHOTO_UNUSABLE  |  app: errorPhotoUnusable, reportFlowPhotoExpired
PHOTO_TOO_LARGE                413  produced: sweep: POST /photos over PHOTO_MAX_UPLOAD_BYTES → 413 PHOTO_TOO_LARGE  |  app: errorPhotoTooLarge
PHOTO_TYPE_UNSUPPORTED         415  produced: sweep: POST /photos not a JPEG → 415 PHOTO_TYPE_UNSUPPORTED  |  app: errorPhotoTypeUnsupported
PHOTO_DELETED                  410  produced: vitest: retention.test.ts  |  app: errorPhotoDeleted
VERIFY_TOKEN_INVALID           401  produced: unreachable — lib/verifyToken is used only by requireVerifyToken/verify.service, neither mounted (/verify is 410)  |  app: n/a — v1 verify links (retired, D11)
VERIFY_TOKEN_REVOKED           410  produced: unreachable — same as VERIFY_TOKEN_INVALID  |  app: n/a — v1 verify links (retired, D11)
INVALID_CREDENTIALS            401  produced: vitest: admin-auth.test.ts  |  app: errorInvalidCredentials, staffLoginFailed
ADMIN_DISABLED                 403  produced: vitest: admin-auth.test.ts  |  app: errorAdminDisabled, staffLoginSuspended
TOKEN_EXPIRED                  401  produced: sweep: GET /me expired session token → 401 TOKEN_EXPIRED  |  app: errorSessionEnded
TOKEN_REVOKED                  401  produced: sweep: GET /me malformed bearer → 401 TOKEN_REVOKED  |  app: errorSessionEnded
COMPLAINT_EXCLUDED             409  produced: unreachable — only in modules/reminders/reminders.service.ts, which no router imports  |  app: n/a — v1 complaints (retired, D11)
COMPLAINT_ANONYMIZED           409  produced: unreachable — same as COMPLAINT_EXCLUDED  |  app: n/a — v1 complaints (retired, D11)
NOT_FOUND                      404  produced: sweep: GET /wards/{unknown id} → 404 NOT_FOUND  |  app: errorNotFound, alertsDetailNotAvailable, discoveryNotAvailable, initiativesNotFound, servicesNotListed, repNotFound
RATE_LIMITED                   429  produced: sweep: issue 11 in a day → 429 RATE_LIMITED  |  app: errorRateLimited, reportFlowQuota
INTERNAL_ERROR                 500  produced: vitest: error-scrub.test.ts  |  app: handled in apps/mobile/lib/core/api/app_error.dart (no direct ARB key found)
SERVICE_UNAVAILABLE            503  produced: sweep: GET /health with the database unreachable → 503 SERVICE_UNAVAILABLE  |  app: errorServiceUnavailable
ENDPOINT_RETIRED               410  produced: vitest: categories.test.ts, status.test.ts +1  |  app: n/a — returned to v1 app builds only
OUTSIDE_SERVICE_AREA           422  produced: sweep: GET /geo/locate far outside → 422 OUTSIDE_SERVICE_AREA  |  app: reportFlowOutsideArea
AUTH_REQUIRED                  401  produced: sweep: GET /me without token → 401 AUTH_REQUIRED  |  app: authReasonGeneric
FIREBASE_TOKEN_INVALID         401  produced: sweep: POST /auth/firebase garbage token → 401 FIREBASE_TOKEN_INVALID  |  app: authErrorTokenInvalid
AGE_CONFIRMATION_REQUIRED      403  produced: sweep: POST /auth/firebase without age confirmation → 403 AGE_CONFIRMATION_REQUIRED  |  app: authErrorAgeRequired
CONSENT_REQUIRED               422  produced: sweep: POST /auth/firebase without core consent → 422 CONSENT_REQUIRED  |  app: authErrorConsentRequired
CORE_CONSENT_REQUIRED          409  produced: sweep: POST /me/consents withdraw core → 409 CORE_CONSENT_REQUIRED  |  app: authErrorCoreConsent
ACCOUNT_SUSPENDED              403  produced: sweep: suspended user signs in → 403 ACCOUNT_SUSPENDED  |  app: authErrorSuspended, reportErrorSuspended
FORBIDDEN                      403  produced: sweep: escalation by a non-follower → 403 FORBIDDEN  |  app: authErrorForbidden, issueActionsForbidden
WARD_NOT_FOUND                 422  produced: sweep: PATCH /me unknown ward → 422 WARD_NOT_FOUND  |  app: authErrorWardNotFound
FIREBASE_UNAVAILABLE           503  produced: vitest: auth.test.ts  |  app: authUnavailable
REP_NO_CONTACT                 422  produced: vitest: relay.test.ts  |  app: handled in apps/mobile/lib/features/ward/application/ward_providers.dart (no direct ARB key found)
MESSAGE_LANGUAGE               422  produced: sweep: profanity in a relay message → 422 MESSAGE_LANGUAGE  |  app: handled in apps/mobile/lib/features/ward/application/ward_providers.dart (no direct ARB key found)
REP_DUPLICATE                  409  produced: sweep: same name, role and term again → 409 REP_DUPLICATE  |  app: MISSING — falls back to the generic error message
REP_PERSONAL_NUMBER            400  produced: sweep: roster entry with a mobile number → 400 REP_PERSONAL_NUMBER  |  app: MISSING — falls back to the generic error message
ELECTION_MODE_FROZEN           409  produced: vitest: scorecard.test.ts, t11-actions.test.ts +1  |  app: wardDashErrorFrozen
WARD_CONFIRMATION_REQUIRED     422  produced: sweep: POST /issues just outside, unconfirmed → 422 WARD_CONFIRMATION_REQUIRED  |  app: reportErrorWardConfirmation
IDEMPOTENCY_KEY_REUSED         409  produced: sweep: POST /issues clientSubmissionId reused by another user → 409 IDEMPOTENCY_KEY_REUSED  |  app: MISSING — falls back to the generic error message
OWN_ISSUE                      409  produced: sweep: me-too on own issue → 409 OWN_ISSUE  |  app: reportErrorOwnIssue
ISSUE_NOT_OPEN                 409  produced: vitest: engage.test.ts, escalation-events.test.ts  |  app: reportErrorNotOpen
CCRS_ALREADY_LINKED            409  produced: sweep: link a different CCRS number → 409 CCRS_ALREADY_LINKED  |  app: linkCcrsConflict
ALERT_STATE_INVALID            409  produced: sweep: submit an alert that is already pending → 409 ALERT_STATE_INVALID  |  app: MISSING — falls back to the generic error message
ALERT_INCOMPLETE               422  produced: vitest: staff-flow.test.ts  |  app: MISSING — falls back to the generic error message
ALERT_APPROVALS_MISSING        409  produced: sweep: moderator publishes before the second approval → 409 ALERT_APPROVALS_MISSING  |  app: MISSING — falls back to the generic error message
ALERT_ALREADY_APPROVED         409  produced: sweep: same moderator approves again → 409 ALERT_ALREADY_APPROVED  |  app: MISSING — falls back to the generic error message
ALERT_SECOND_APPROVER_ADMIN    403  produced: sweep: moderator gives the second approval → 403 ALERT_SECOND_APPROVER_ADMIN  |  app: MISSING — falls back to the generic error message
ALERT_ALREADY_SUPERSEDED       409  produced: vitest: lifecycle.test.ts  |  app: MISSING — falls back to the generic error message
SIGNED_IN_USE_ME               409  produced: sweep: signed-in user on the device subscriptions endpoint → 409 SIGNED_IN_USE_ME  |  app: MISSING — falls back to the generic error message
INITIATIVE_NOT_OPEN            409  produced: sweep: RSVP to a cancelled drive → 409 INITIATIVE_NOT_OPEN  |  app: handled in apps/mobile/lib/features/initiatives/application/initiatives_providers.dart (no direct ARB key found)
INITIATIVE_FULL                409  produced: sweep: RSVP to a full drive → 409 INITIATIVE_FULL  |  app: handled in apps/mobile/lib/features/initiatives/application/initiatives_providers.dart (no direct ARB key found)
INITIATIVE_STARTED             409  produced: vitest: t14-error-codes.test.ts  |  app: handled in apps/mobile/lib/features/initiatives/application/initiatives_providers.dart (no direct ARB key found)
INITIATIVE_NOT_STARTED         409  produced: sweep: admin marks attendance before start → 409 INITIATIVE_NOT_STARTED  |  app: MISSING — falls back to the generic error message
INVALID_TRANSITION             409  produced: sweep: disallowed transition (acknowledged → acknowledged) → 409 INVALID_TRANSITION  |  app: handled in apps/mobile/lib/features/staff/shared/staff_widgets.dart (no direct ARB key found)
SLUG_TAKEN                     409  produced: sweep: same slug again → 409 SLUG_TAKEN  |  app: staffContentErrorSlugTaken
STALE_STATUS                   409  produced: sweep: stale expectedStatus → 409 STALE_STATUS  |  app: issueActionsStale
FORBIDDEN_ROLE                 403  produced: sweep: citizen (not reporter) changes status → 403 FORBIDDEN_ROLE  |  app: issueActionsForbidden
OUT_OF_WARD                    403  produced: unreachable — superseded: the TASK-11 pre-transition hook returns WARD_OUT_OF_SCOPE before lifecycle.service can throw it  |  app: issueActionsForbidden
VERIFY_NOT_OPEN                409  produced: vitest: verification.test.ts  |  app: issueActionsVerifyClosed
ALREADY_ANSWERED_TODAY         409  produced: sweep: second verification answer  |  app: issueActionsVerifyAlready
TOO_FAR_FROM_ISSUE             422  produced: sweep: verify more than 100 m away → 422 TOO_FAR_FROM_ISSUE  |  app: issueActionsVerifyTooFar
LOCATION_TOO_INACCURATE        422  produced: sweep: verify with 80 m accuracy → 422 LOCATION_TOO_INACCURATE  |  app: issueActionsVerifyInaccurate
CCRS_NOT_LINKED                409  produced: sweep: POST /issues/{id}/ccrs/closed before linking → 409 CCRS_NOT_LINKED  |  app: MISSING — falls back to the generic error message
WARD_OUT_OF_SCOPE              403  produced: sweep: representative dashboard for another ward → 403 WARD_OUT_OF_SCOPE  |  app: wardDashErrorOutOfScope
ISSUE_STATE_INVALID            409  produced: sweep: reject it again → 409 ISSUE_STATE_INVALID  |  app: handled in apps/mobile/lib/features/staff/shared/staff_widgets.dart (no direct ARB key found)
MERGE_INVALID                  422  produced: sweep: merge an issue into itself → 422 MERGE_INVALID  |  app: MISSING — falls back to the generic error message
SELF_ROLE_CHANGE               409  produced: vitest: users-flags.test.ts  |  app: MISSING — falls back to the generic error message
SETTING_UNKNOWN                400  produced: sweep: admin PUT /staff/settings/{unknown} → 400 SETTING_UNKNOWN  |  app: MISSING — falls back to the generic error message
EXPORT_TOO_LARGE               413  produced: vitest: t14-error-codes.test.ts  |  app: staffExportTooMany
FLAG_QUOTA                     429  produced: vitest: t14-error-codes.test.ts  |  app: handled in apps/mobile/lib/features/staff/flags/flag_content_sheet.dart (no direct ARB key found)
SELF_SUSPEND                   409  produced: sweep: moderator suspends self → 409 SELF_SUSPEND  |  app: MISSING — falls back to the generic error message
USER_STATE_INVALID             409  produced: sweep: suspend again → 409 USER_STATE_INVALID  |  app: MISSING — falls back to the generic error message
ROLE_CHANGE_INVALID            422  produced: sweep: admin changes a representative's role → 422 ROLE_CHANGE_INVALID  |  app: MISSING — falls back to the generic error message
WARD_REQUIRED                  400  produced: sweep: GET /feed without ward (visitor) → 400 WARD_REQUIRED  |  app: MISSING — falls back to the generic error message
CLAIM_ALREADY_PENDING          409  produced: sweep: second claim on the same profile while one is pending → 409 CLAIM_ALREADY_PENDING  |  app: repClaimSeeMine, repClaimErrorPending
REPRESENTATIVE_ALREADY_VERIFIED 409  produced: sweep: claim a verified profile → 409 REPRESENTATIVE_ALREADY_VERIFIED  |  app: repClaimErrorVerified
REPRESENTATIVE_TERM_ENDED      422  produced: vitest: t11-claims.test.ts  |  app: repClaimErrorTermEnded
ROLE_CONFLICT                  409  produced: vitest: t11-claims.test.ts  |  app: repClaimErrorRoleConflict
CLAIM_NOT_PENDING              409  produced: sweep: decide it again → 409 CLAIM_NOT_PENDING  |  app: repClaimConflict
NOT_VERIFIED                   409  produced: sweep: revoke verification of an unverified profile → 409 NOT_VERIFIED  |  app: MISSING — falls back to the generic error message
ALREADY_REPLIED                409  produced: sweep: second reply → 409 ALREADY_REPLIED  |  app: MISSING — falls back to the generic error message
BAD_SIGNATURE                  401  produced: sweep: webhook without signature → 401 BAD_SIGNATURE  |  app: n/a — mail webhook only (server to server)
PASS  every reachable ERROR_CODES entry is produced by the sweep or a Vitest test
INFO  unreachable codes (findings): INVITE_CODE_INVALID, INVITE_CODE_TAKEN, VERIFY_TOKEN_INVALID, VERIFY_TOKEN_REVOKED, COMPLAINT_EXCLUDED, COMPLAINT_ANONYMIZED, OUT_OF_WARD
INFO  user-facing codes without an app message (report only; mobile not edited): REP_DUPLICATE, REP_PERSONAL_NUMBER, IDEMPOTENCY_KEY_REUSED, ALERT_STATE_INVALID, ALERT_INCOMPLETE, ALERT_APPROVALS_MISSING, ALERT_ALREADY_APPROVED, ALERT_SECOND_APPROVER_ADMIN, ALERT_ALREADY_SUPERSEDED, SIGNED_IN_USE_ME, INITIATIVE_NOT_STARTED, CCRS_NOT_LINKED, MERGE_INVALID, SELF_ROLE_CHANGE, SETTING_UNKNOWN, SELF_SUSPEND, USER_STATE_INVALID, ROLE_CHANGE_INVALID, WARD_REQUIRED, NOT_VERIFIED, ALREADY_REPLIED

== Env-var sweep
APP_ENV                            example:yes  required → startup fails: Config error: APP_ENV Invalid option: expected one of "development"|"production"
API_HOST                           example:yes  required → startup fails: Config error: API_HOST Invalid input: expected string, received undefined
API_PORT                           example:yes  required → startup fails: Config error: API_PORT Invalid input: expected number, received NaN
DATABASE_URL                       example:yes  required → startup fails: Config error: DATABASE_URL Invalid input: expected string, received undefined
JWT_SECRET                         example:yes  required → startup fails: Config error: JWT_SECRET Invalid input: expected string, received undefined
JWT_ISSUER                         example:yes  required → startup fails: Config error: JWT_ISSUER Invalid input: expected string, received undefined
JWT_AUDIENCE                       example:yes  required → startup fails: Config error: JWT_AUDIENCE Invalid input: expected string, received undefined
JWT_EXPIRES_IN                     example:yes  required → startup fails: Config error: JWT_EXPIRES_IN Invalid input: expected string, received undefined
STORAGE_DRIVER                     example:yes  required → startup fails: Config error: STORAGE_DRIVER Invalid option: expected one of "local"|"cloudflare_r2"
PHOTO_STORAGE_DIR                  example:yes  required → startup fails: Config error: PHOTO_STORAGE_DIR is required when STORAGE_DRIVER=local
R2_ACCOUNT_ID                      example:yes  optional (default)
R2_ACCESS_KEY_ID                   example:yes  optional (default)
R2_SECRET_ACCESS_KEY               example:yes  optional (default)
R2_BUCKET                          example:yes  optional (default)
R2_ENDPOINT                        example:yes  optional (default)
DEPLOY_ENV                         example:yes  optional (default)
SENTRY_DSN                         example:yes  optional (default)
SENTRY_TRACES_SAMPLE_RATE          example:yes  optional (default)
RETENTION_CLOSED_PHOTO_DAYS        example:yes  optional (default)
RETENTION_NOTIFICATION_DAYS        example:yes  optional (default)
RETENTION_LOG_DAYS                 example:yes  optional (default)
REOPEN_WINDOW_DAYS                 example:yes  optional (default)
PHOTO_MAX_UPLOAD_BYTES             example:yes  required → startup fails: Config error: PHOTO_MAX_UPLOAD_BYTES Invalid input: expected number, received NaN
PHOTO_MAX_EDGE_PX                  example:yes  required → startup fails: Config error: PHOTO_MAX_EDGE_PX Invalid input: expected number, received NaN
UNATTACHED_PHOTO_TTL_HOURS         example:yes  required → startup fails: Config error: UNATTACHED_PHOTO_TTL_HOURS Invalid input: expected number, received NaN
REMINDER_INTERVAL_DAYS             example:yes  required → startup fails: Config error: REMINDER_INTERVAL_DAYS Invalid input: expected number, received NaN
VERIFY_LINK_BASE                   example:yes  required → startup fails: Config error: VERIFY_LINK_BASE Invalid input: expected string, received undefined
VERIFY_DISTANCE_WARN_M             example:yes  optional (default)
CONSENT_TEXT_VERSIONS              example:yes  required → startup fails: Config error: CONSENT_TEXT_VERSIONS Invalid input: expected string, received undefined
REMINDER_TEMPLATE_VERSION          example:yes  required → startup fails: Config error: REMINDER_TEMPLATE_VERSION Invalid input: expected "v1"
CORS_ORIGINS                       example:yes  optional (default)
TRUST_PROXY                        example:yes  required → startup fails: Config error: TRUST_PROXY Invalid option: expected one of "true"|"false"
LOG_LEVEL                          example:yes  required → startup fails: Config error: LOG_LEVEL Invalid option: expected one of "fatal"|"error"|"warn"|"info"|"debug"|"trace"
LOG_FILE_DIR                       example:yes  optional (default)
SEED_ADMIN_EMAIL                   example:yes  optional (default)
SEED_ADMIN_PASSWORD                example:yes  optional (default)
GEO_NEAREST_MAX_M                  example:yes  optional (default)
FIREBASE_AUTH_MODE                 example:yes  optional (default)
FIREBASE_PROJECT_ID                example:yes  optional (default)
FIREBASE_AUTH_EMULATOR_HOST        example:yes  optional (default)
GOOGLE_APPLICATION_CREDENTIALS     example:yes  optional (default)
USER_JWT_AUDIENCE                  example:yes  optional (default)
USER_JWT_EXPIRES_IN                example:yes  optional (default)
PUSH_DRIVER                        example:yes  optional (default)
CONSENT_TEXT_VERSIONS_V2           example:yes  optional (default)
GRIEVANCE_EMAIL                    example:yes  optional (default)
EMAIL_DRIVER                       example:yes  optional (default)
EMAIL_FILE_DIR                     example:yes  optional (default)
SES_REGION                         example:yes  optional (default)
SES_FROM                           example:yes  optional (default)
EMAIL_OPS_ADDRESS                  example:yes  optional (default)
PUBLIC_WEB_BASE_URL                example:yes  optional (default)
RELAY_PER_REP_DAILY                example:yes  optional (default)
RELAY_PER_USER_DAILY               example:yes  optional (default)
SCORECARD_MIN_SAMPLE               example:yes  optional (default)
DUPLICATE_RADIUS_M                 example:yes  optional (default)
DUPLICATE_WINDOW_DAYS              example:yes  optional (default)
ISSUE_MAX_PHOTOS                   example:yes  optional (default)
QUOTA_ISSUES_PER_DAY               example:yes  optional (default)
QUOTA_ME_TOO_PER_DAY               example:yes  optional (default)
QUOTA_VERIFICATIONS_PER_DAY        example:yes  optional (default)
QUOTA_MESSAGES_PER_REP_PER_DAY     example:yes  optional (default)
QUOTA_PHOTOS_PER_DAY               example:yes  optional (default)
AMC_PROBLEMS_URL                   example:yes  optional (default)
AMC_PROBLEMS_MIN_INTERVAL_HOURS    example:yes  optional (default)
AMC_FETCH_CONTACT_EMAIL            example:yes  optional (default)
JOBS_ENABLED                       example:yes  optional (default)
ALERT_MAX_VALIDITY_DAYS            example:yes  optional (default)
QUIET_HOURS                        example:yes  optional (default)
APP_TIMEZONE                       example:yes  optional (default)
SACHET_ENABLED                     example:yes  optional (default)
SACHET_FEED_URL                    example:yes  optional (default)
SACHET_POLL_MINUTES                example:yes  optional (default)
IMD_ENABLED                        example:yes  optional (default)
IMD_DISTRICT_WARNINGS_URL          example:yes  optional (default)
VERIFY_RADIUS_M                    example:yes  optional (default)
VERIFY_MAX_ACCURACY_M              example:yes  optional (default)
NOT_FIXED_THRESHOLD                example:yes  optional (default)
CCRS_REOPEN_HOURS                  example:yes  optional (default)
CCRS_REMINDER_AFTER_HOURS          example:yes  optional (default)
QUOTA_STATUS_CHANGES_PER_DAY       example:yes  optional (default)
QUOTA_ESCALATIONS_PER_DAY          example:yes  optional (default)
STAFF_WEB_ORIGINS                  example:yes  optional (default)
AUDIT_LOG_FILE                     example:yes  optional (default)
AUDIT_RETENTION_DAYS               example:yes  optional (default)
EXPORT_MAX_ROWS                    example:yes  optional (default)
EXPORT_HMAC_SECRET                 example:yes  optional (default)
FEED_CACHE_SECONDS                 example:yes  optional (default)
MAP_CLUSTER_MAX_ZOOM               example:yes  optional (default)
MAP_POINTS_MAX                     example:yes  optional (default)
ISSUES_PAGE_MAX                    example:yes  optional (default)
REP_CLAIM_MAX_PER_DAY              example:yes  optional (default)
REP_EXPORT_MAX_PER_HOUR            example:yes  optional (default)
MAIL_INBOUND_SECRET                example:yes  optional (default)
MAIL_REPLY_DOMAIN                  example:yes  optional (default)
REP_DASHBOARD_HOTSPOT_CELL_M       example:yes  optional (default)
PASS  every src/config variable is listed in apps/api/.env.example
PASS  removing any required variable fails startup with a "Config error: <NAME>" message

SUMMARY  305 passed, 0 failed, 305 checks
```
