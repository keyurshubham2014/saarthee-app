# TASK-10: End-to-End Verification, Coverage Audit & Gap Closure

| Field | Value |
|---|---|
| Task ID | TASK-10 |
| Status | In Review |
| Priority | P0 |
| Size | L |
| Depends On | TASK-08, TASK-09 |
| Blocks | None |
| Requirement IDs | REQ-N-017, REQ-N-018, REQ-N-019, REQ-S-026, REQ-S-027, REQ-S-036, REQ-O-014, REQ-O-015, REQ-O-016, REQ-O-020, REQ-O-023 |
| Primary Spec Refs | 06-security-testing.md §10, 06-security-testing.md §12.3, 07-implementation-roadmap.md §3 Stage E, 07-implementation-roadmap.md §7, 05-devops-infrastructure.md §4.5–4.6 |
| Last Updated | 2026-10-03 |

## 1. Objective

Prove, with recorded evidence, that every feature and requirement in the specification works in the running system on real devices, and close every gap found on the way. At the end of this task:
- the coverage-verification layer reports 100% (every active requirement is Pass, Fixed or Deferred with a recorded decision);
- the 06 §12.3 manual release checklist passes on a low-end Android phone and an iPhone;
- no stubs, placeholders or hard-coded values remain;
- every deviation from the spec is written back into the spec documents.

This is milestone **M5 — Device-ready** (07 §4).

## 2. Scope

### In Scope
- **Coverage audit (verification layer):**
  - run both checkers;
  - walk every active registry requirement against the running system;
  - independently sweep the spec inventories so nothing the registry missed slips through: 02 §3.1 routes, 03 §2.2 endpoints, 03 §9.1 error codes, 03 §11 events, 05 §2.2 env vars, 04 §8 seeds.
- **Gap closure:**
  - fix every `Fail` / `Not Verified` row and every S1/S2 bug (06 §12.2);
  - remove TODO/FIXME/stub/mock/placeholder code, hard-coded colours and hard-coded user-facing strings.
- **Device verification:**
  - physical low-end Android phone over LAN;
  - iOS simulator, then a physical iPhone;
  - real WhatsApp deep-link test with the outcome recorded, and the manual-code fallback;
  - performance targets checked by hand.
- **Accessibility audit:** TalkBack and VoiceOver through report and verify, largest font, grayscale statuses, 320-px layouts, focus to the error summary.
- **Privacy and security sweep:**
  - the full 06 §12.3 checklist;
  - phone-number exposure audit (REQ-S-026);
  - admin audit-log completeness (REQ-S-027);
  - `npm audit`, `flutter pub outdated`, Dependabot.
- **Optional:** Vitest safety-net tests in 06 §8.1 order (P2, only if time allows).
- **Close-out:**
  - spec Decisions & Assumptions tables updated;
  - all task files and the summary at Complete / 100%;
  - `check_coverage.py` exits 0;
  - the validator passes.

### Out of Scope
- Deployment, HTTPS, App/Universal Links, Cloudflare storage and store release (REQ-O-022, deferred; 05 §9).
- Gujarati/Hindi translations (REQ-N-024), release obfuscation (REQ-N-025), screenshot blocking (REQ-S-037) and phone field encryption (REQ-S-038). All are deferred.
- New features not in the registry. If the inventory sweep finds a spec item with no requirement, it is **added** (new REQ ID owned by TASK-10) rather than dropped. See step 6.
- Product and legal decisions (H2 threshold, consent wording, retention, real AMC categories). These are pilot blockers recorded in the summary's Open Questions, not build work.

## 3. Prerequisites

- TASK-01…TASK-09 are all `Complete` on the summary board. The coverage matrix rows owned by those tasks should already be `Pass`. This task re-verifies them end to end.
- **Devices (open needs, from the summary's Open Questions):**
  - a **low-end Android test phone**, model to be chosen (02 F3 — blocker for REQ-N-017 and the Android half of REQ-O-014);
  - a **Mac with Xcode and Apple code signing** for a physical iPhone. A free personal team may allow short-lived installs; check Apple's current rules (05 §4.5);
  - **WhatsApp installed on a second phone** (the "operator" phone) to send a real reminder to the test phone (REQ-O-015).
- Phones on the same **trusted** Wi-Fi as the dev machine; the API bound to the LAN and the DB to localhost only (06 §5.1).
- Development seed data plus team test reports only. **No real citizen data** (06 §5.1).
- Tools: `exiftool` (or any metadata viewer), `psql` or a SQL client, `grep`/`rg`, Excel or Google Sheets.
- `REMINDER_INTERVAL_DAYS` can be set temporarily to `0` (or seed timestamps backdated) so complaints become Due immediately. Restore it afterwards.

## 4. Dependencies

| Task | Why it is required |
|---|---|
| TASK-08 | Complaint list/detail, exclusion, anonymization and revoke must exist to run the admin-data, anonymize and privacy checks |
| TASK-09 | Export and reference-data screens must exist to run the CSV, invite-code and category checks. Together with TASK-08 this transitively requires TASK-01…07 |

## 5. Technical Context

### 5.1 Requirements Covered

| Req ID | Requirement | Source |
|---|---|---|
| REQ-N-017 | Performance targets checked by hand on a low-end Android phone (cold start ≤ 3 s, tap response < 100 ms, compression ≤ 2 s, 200–600 KB photos) | 02 §8.1, 06 §11 |
| REQ-N-018 | Accessibility audit: TalkBack and VoiceOver run-through of report and verify, largest font, statuses readable in grayscale | 06 §10.1, 07 D6 |
| REQ-N-019 | Optional Vitest safety-net tests in §8.1 order (rates, idempotency, verify access, redaction, CSV, due boundary) | 06 §8.1 |
| REQ-S-026 | Phone number exposure: never in logs, events, verify responses or list items; only in complaint detail and the reminder response; in CSV only with `includePhone=true` | 06 §4.2, 03 §2.3 |
| REQ-S-027 | Admin actions (reminder, exclusion, anonymization, export, category/invite-code change, logout-all) logged at `info` with admin ID and target ID | 03 §9.2, 06 T11 |
| REQ-S-036 | Dependency audit before shared builds: `npm audit --audit-level=high`, `flutter pub outdated`; Dependabot alerts on | 06 §5.3 |
| REQ-O-014 | Full loop works on a physical low-end Android phone (LAN `API_BASE_URL`) and on iOS simulator + iPhone | 05 §4.5–4.6, 07 E1–E2 |
| REQ-O-015 | Deep link tested from a real WhatsApp message; if not tappable, manual code entry confirmed; result recorded | 01 A14, 07 E3 |
| REQ-O-016 | Manual release checklist (06 §12.3) passes on both phones; S1/S2 bugs fixed | 06 §12, 07 E5 |
| REQ-O-020 | Deviations from the spec recorded in the affected document's Decisions & Assumptions table | 07 §7.2 |
| REQ-O-023 | Feature-coverage verification layer: every active requirement in the registry is verified against the running system and recorded (Pass / Fixed / Deferred-with-decision) in `docs/tasks/coverage-verification.md`; `check_coverage.py` reports 0 unverified | 07 §7.3, 06 §12 |

TASK-06 is the primary owner of REQ-S-026, and TASK-05 of REQ-S-027. This task re-verifies both system-wide.

### 5.2 Data Contracts

No schema change is expected. If gap closure needs one, it gets its own forward migration (04 §7.2: never edit an applied migration). Queries used in the audit:

```sql
-- Phone numbers or tokens leaking into analytics (REQ-S-026, REQ-S-014)
SELECT id, name, properties FROM events
WHERE properties::text ~ '\+91|[6-9][0-9]{9}' OR properties::text ~* 'token|phone|note|lat|lng|code';

-- Rates hand count for the trusted row (06 §12.3 "Correct numbers")
SELECT * FROM pilot_rates_v ORDER BY 1;

-- Every complaint status represented in the seed (04 §8)
SELECT status, count(*) FROM complaint_status_v GROUP BY status;

-- Stored photos with deleted files after anonymization
SELECT id, deleted_at FROM photos WHERE deleted_at IS NOT NULL;
```

### 5.3 API Contracts

The endpoint inventory sweep (03 §2.2). Every row must be exercised against the running API, including its main error code, and ticked in the Progress log. "Owner" is the task that built it.

| # | Method | Endpoint | Auth | Key errors to exercise | Owner |
|---|---|---|---|---|---|
| 1 | GET | /health | No | 503 with DB stopped | TASK-01 |
| 2 | GET | /categories | No | 429 | TASK-04 |
| 3 | POST | /invite-codes/validate | No | 404 `INVITE_CODE_INVALID` | TASK-03 |
| 4 | POST | /photos | No | 413, 415 | TASK-04 |
| 5 | POST | /reports | No | 400, 422 `PHOTO_UNUSABLE`/`CATEGORY_INACTIVE`, 200 on retry | TASK-04 |
| 6 | GET | /verify/complaint | Verify token | 401, 410 | TASK-07 |
| 7 | GET | /verify/complaint/photo | Verify token | 401, 410 | TASK-07 |
| 8 | POST | /verify/photos | Verify token | 401, 413, 415 | TASK-07 |
| 9 | POST | /verify/submissions | Verify token | 422 other-complaint photo, 200 on retry | TASK-07 |
| 10 | POST | /events | No | 400 (> 50 events) | TASK-03 |
| 11 | POST | /admin/auth/login | No | 401, 403, 429 | TASK-05 |
| 12 | GET | /admin/me | JWT | 401 | TASK-05 |
| 13 | POST | /admin/auth/logout-all | JWT | old token → 401 `TOKEN_REVOKED` | TASK-05 |
| 14 | GET | /admin/complaints | JWT | 400 bad filter | TASK-06/08 |
| 15 | GET | /admin/complaints/{id} | JWT | 404 | TASK-08 |
| 16 | GET | /admin/complaints/{id}/photo | JWT | 410 `PHOTO_DELETED` | TASK-08 |
| 17 | GET | /admin/verifications/{id}/photo | JWT | 404, 410 | TASK-08 |
| 18 | POST | /admin/complaints/{id}/reminders | JWT | 409 `COMPLAINT_EXCLUDED`, 409 `COMPLAINT_ANONYMIZED` | TASK-06 |
| 19 | POST | /admin/reminders/{id}/revoke | JWT | 404 | TASK-08 |
| 20 | PATCH | /admin/complaints/{id}/exclusion | JWT | 400 missing reason | TASK-08 |
| 21 | POST | /admin/complaints/{id}/anonymize | JWT | 400 without `confirm` | TASK-08 |
| 22 | GET | /admin/rates | JWT | 401 | TASK-06 |
| 23 | GET | /admin/export | JWT | 400 bad type | TASK-09 |
| 24 | GET | /admin/invite-codes | JWT | 401 | TASK-09 |
| 25 | POST | /admin/invite-codes | JWT | 409 `INVITE_CODE_TAKEN` | TASK-09 |
| 26 | PATCH | /admin/invite-codes/{id} | JWT | 404 | TASK-09 |
| 27 | GET | /admin/categories | JWT | 401 | TASK-09 |
| 28 | POST | /admin/categories | JWT | 409 | TASK-09 |
| 29 | PATCH | /admin/categories/{id} | JWT | 404, 409 | TASK-09 |

**Error-code sweep (03 §9.1).** Each code must be produced at least once and shown with its user-facing message in the app (where user-facing):

`VALIDATION_FAILED`, `INVITE_CODE_INVALID`, `INVITE_CODE_TAKEN`, `CATEGORY_INACTIVE`, `PHOTO_UNUSABLE`, `PHOTO_TOO_LARGE`, `PHOTO_TYPE_UNSUPPORTED`, `PHOTO_DELETED`, `VERIFY_TOKEN_INVALID`, `VERIFY_TOKEN_REVOKED`, `INVALID_CREDENTIALS`, `ADMIN_DISABLED`, `TOKEN_EXPIRED`, `TOKEN_REVOKED`, `COMPLAINT_EXCLUDED`, `COMPLAINT_ANONYMIZED`, `NOT_FOUND`, `RATE_LIMITED`, `INTERNAL_ERROR`, `SERVICE_UNAVAILABLE`.

**Event sweep (03 §11).** Each event row must appear in the `events` table with only its allowed properties:

| Event | Sent by | Allowed properties |
|---|---|---|
| `invite_code_entered` | App | `{valid}` |
| `report_opened` | App | — |
| `ccrs_handoff_clicked` | App | `{target}` |
| `report_submitted` | Server | — |
| `reminder_sent` | Server | — |
| `verify_opened` | Server | — |
| `deep_link_failed` | App | `{reason}` |
| `verify_submitted` | Server | `{result}` |
| `record_flagged` | Server | `{isExcluded, reason}` |

**Env-var sweep (05 §2.2).**

API: every variable must be read from config, validated at startup, listed in `.env.example`, and have its behaviour observable:
`APP_ENV`, `API_HOST`, `API_PORT`, `DATABASE_URL`, `JWT_SECRET`, `JWT_ISSUER`, `JWT_AUDIENCE`, `JWT_EXPIRES_IN`, `STORAGE_DRIVER`, `PHOTO_STORAGE_DIR`, `PHOTO_MAX_UPLOAD_BYTES`, `PHOTO_MAX_EDGE_PX`, `UNATTACHED_PHOTO_TTL_HOURS`, `REMINDER_INTERVAL_DAYS`, `VERIFY_LINK_BASE`, `VERIFY_DISTANCE_WARN_M`, `CONSENT_TEXT_VERSIONS`, `REMINDER_TEMPLATE_VERSION`, `CORS_ORIGINS`, `TRUST_PROXY`, `LOG_LEVEL`, `SEED_ADMIN_EMAIL`, `SEED_ADMIN_PASSWORD`.

Flutter `--dart-define`: `APP_ENV`, `API_BASE_URL`, `DEEP_LINK_SCHEME`, `CCRS_WEB_URL`, `CCRS_WHATSAPP_NUMBER`, `AMC_HELPLINE`.

### 5.4 UI Surfaces & States

**Route inventory sweep (02 §3.1, 27 routes).** Each route must be reached on Android and iOS and show its default, loading, empty (lists), error, offline and unauthorized (admin) states where applicable.

| Citizen | Verify | Admin |
|---|---|---|
| `/welcome`, `/invite`, `/`, `/about` | `/verify?t=<token>`, `/verify/enter-code`, `/verify/answer`, `/verify/photo`, `/verify/note`, `/verify/check`, `/verify/done` | `/admin/login`, `/admin` (Due), `/admin/complaints`, `/admin/complaints/:id`, `/admin/rates`, `/admin/more`, `/admin/invite-codes`, `/admin/categories`, `/admin/export` |
| `/report/category`, `/report/file-with-amc`, `/report/number`, `/report/photo`, `/report/phone`, `/report/check`, `/report/done` | | |

Accessibility audit targets (02 §2.3):
- TalkBack (Android) and VoiceOver (iOS) through the whole report and verify flows;
- the largest system text size on every route;
- grayscale display mode for `StatusChip` and `BeforeAfterCard` stamps;
- 320-px width (compact phone breakpoint, 02 §2.2);
- focus moving to `ErrorSummary` on a failed submit;
- reduced-motion setting respected.

### 5.5 Permissions & Roles

Re-verify the authorization matrix (03 §3.3) end to end:
- a citizen with no token is rejected on every `/verify/*` and `/admin/*` endpoint;
- a verify token for complaint A cannot read complaint B's summary or photo, or attach a photo uploaded under B's token;
- the admin cannot submit verifications (no such admin endpoint exists in v1);
- every admin endpoint rejects a missing, expired or revoked JWT with 401.

Phone exposure (REQ-S-026):

| Surface | Phone allowed? |
|---|---|
| `GET /admin/complaints` items | No |
| `GET /admin/complaints/{id}` | Yes |
| Reminder create response | Yes (`phoneE164`) |
| All `/verify/*` responses | No |
| `events.properties` | No |
| API logs (all levels) | No |
| CSV export | Only with `includePhone=true` |

### 5.6 Assumptions

- ASSUMPTION: If no physical iPhone or Apple signing is available, iOS is verified on the simulator and the iPhone half of REQ-O-014/REQ-O-016 is recorded as `Blocked` (in the summary, with the reason), not as `Pass`. The task cannot be `Complete` until it is resolved or the founder records a `Deferred` decision in the coverage matrix. Rationale: never claim unverified results. If wrong, the founder may accept a simulator-only result as a recorded decision.
- ASSUMPTION: "Performance targets" are measured with a stopwatch or screen recording on the chosen low-end phone (02 §8.1 says "measure by hand"). No profiling tooling is required. If wrong, add Flutter DevTools timings.
- ASSUMPTION: A gap is "large" when it is a whole missing feature (a screen, endpoint or workflow). In that case the owning task is reopened (`In Progress`) rather than absorbed silently here. Small gaps are fixed here and recorded as `Fixed`. If wrong, all fixes land in TASK-10.
- ASSUMPTION: Optional Vitest tests (REQ-N-019) are P2. If time does not allow them, the REQ-N-019 row is set to `Deferred` with the founder's decision and date, which satisfies `check_coverage.py`.

## 6. Implementation Steps

**Phase A — Coverage audit (the verification layer)**

1. **Run both checkers and capture baselines.** Run `python3 docs/tasks/validate_tasks.py docs/tasks/` and `python3 docs/tasks/check_coverage.py`, and paste both outputs into the Progress log. Every row that is not `Pass` becomes a work item.
2. **Bring the stack up from clean.** `db:reset` → migrate → seed → `api:dev`. Install the debug app on the Android emulator. Confirm `GET /health` reports the DB as ok.
3. **Walk the registry category by category against the running system.** Order: REQ-F (79) → REQ-D (17) → REQ-N (23) → REQ-S (36) → REQ-O (22). For each row:
   - perform the check named in the owning task's §8 (cite its check ID);
   - set the matrix status to `Pass` or `Fail` with evidence and date.

   Use `check_coverage.py --task TASK-NN` to work task by task.
4. **Inventory sweep 1 — routes.** Reach every one of the 27 routes in §5.4 and confirm their states.
5. **Inventory sweep 2 — contracts.**
   - Exercise all 29 endpoints in §5.3 with their key error codes.
   - Produce every one of the 20 error codes.
   - Generate all 9 events and confirm their properties with the events SQL in §5.2.
   - Check every API env var is validated (remove one and confirm startup fails clearly) and listed in `.env.example`, and every dart-define has a value in each run configuration.
   - Confirm the seed covers every status (04 §8) via the `complaint_status_v` query, plus excluded and duplicate-CCRS rows.
6. **Registry gaps.** If any sweep finds a spec item with no registry requirement:
   - add a new sequential REQ ID to `requirements-registry.md` with `Covered By: TASK-10`;
   - add it to this file's Requirement IDs and §5.1;
   - run `python3 docs/tasks/check_coverage.py --sync`;
   - re-run the validator.

**Phase B — Gap closure**

7. **Fix every `Fail` / `Not Verified` row.**
   - Small gaps: fix, commit `TASK-10: fix <REQ-ID> …`, and set the row to `Fixed` with the commit hash.
   - Whole-feature gaps: reopen the owning task (`In Progress`, reason in the summary's **Blocked/Change Log**), complete it, then return here.
8. **Stub and placeholder sweep.** Remove or resolve every hit. Each remaining hit needs a written justification in the Progress log.
   - `rg -n "TODO|FIXME|XXX|stub|mock|fake|placeholder|lorem" apps/ --glob '!**/*.lock'`. The categories "Placeholder list" note is spec-required (02 §4.22) and allowed.
   - `rg -n "Color\(0x|Colors\." apps/mobile/lib --glob '!**/theme/**'`: no colours outside the theme tokens.
   - `rg -n "Text\(\s*['\"]" apps/mobile/lib`: no user-facing string literals; all strings go through ARB/localizations.
   - `rg -n "console\.log" apps/api/src`: use the structured logger only.
   - Confirm no hard-coded URLs, ports, intervals or limits in code that belong to 05 §2.2 config.
9. **Bug triage per 06 §12.2.** S1 (data loss, wrong H1/H2, personal data exposed, crash in report or verify) and S2 (P0 flow blocked) are fixed before close. S3 bugs are logged in the summary's Open Questions with the build version.

**Phase C — Device verification**

10. **Android physical phone (REQ-O-014).**
    - Run configuration with `API_BASE_URL=http://<LAN-IP>:4000/api/v1`.
    - Confirm the debug network-security config allows cleartext **only** for the dev machine's address.
    - Run the full loop: first launch → invite → report (kill the app during the CCRS hand-off, reopen, draft intact) → admin login → Due → Send reminder → verify (Not fixed with photo) → Rates shows the updated H2.
11. **iOS (REQ-O-014).** On the iOS simulator, then on a physical iPhone:
    - ATS exception present only in the Debug configuration;
    - camera and location usage strings in plain language;
    - `saarthee` URL type registered;
    - same full loop as Android.

    If signing is unavailable, record `Blocked` per §5.6.
12. **Real WhatsApp deep link (REQ-O-015).**
    - From the operator phone, send the reminder via "Open WhatsApp" to the test phone. Tap the `saarthee://verify?t=…` link in WhatsApp on Android and on iPhone.
    - Record "tappable: yes/no" per platform in the Progress log and in `docs/01-project-overview.md` Decisions row 14.
    - If not tappable, complete the verify via "Answer a follow-up" → paste link/code, and confirm `deep_link_failed` is recorded.
13. **Performance by hand (REQ-N-017).** On the low-end Android phone:
    - cold start to Home ≤ 3 s;
    - step transitions respond < 100 ms with no visible stutter;
    - photo compression ≤ 2 s;
    - compressed photo 200–600 KB (check `photos.byte_size`);
    - note the app download size.

    Record the measurements; any miss becomes an S3 note or a fix.

**Phase D — Accessibility audit (REQ-N-018)**

14. Run TalkBack through report and verify, then VoiceOver through the same:
    - every control is labelled;
    - photos are described ("Photo of the problem, taken …");
    - "Step n of N" is announced;
    - errors are announced;
    - focus jumps to the error summary on a failed submit.

    Then check the largest system font on all 27 routes (no clipping), grayscale mode (statuses readable by icon and word), 320-px width, and reduced motion. Fix failures as S2 (citizen flows) or S3 (admin).

**Phase E — Privacy and security sweep**

15. **Release checklist (REQ-O-016).** Run every item of the 06 §12.3 checklist in §7.2 on both phones. Record pass/fail per device with the build version in the Progress log.
16. **Phone exposure audit (REQ-S-026).**
    - Create a report with test phone `+91 98765 43210` and a reminder.
    - Then: `rg -n "9876543210|98765 43210" <api log file>` → 0 hits.
    - Run the events SQL in §5.2 → 0 rows.
    - Confirm `curl` of `GET /admin/complaints` contains no `phone`, and all three `/verify/*` GET/POST responses contain no phone, coordinates, source tag or invite code.
    - Export without `includePhone` has no phone column.
17. **Admin audit-log completeness (REQ-S-027).** Perform one of each admin action, then confirm there is exactly one `info` line for each, carrying `adminId` and the target ID (or export type) and no bodies:
    - reminder create;
    - reminder revoke;
    - exclude;
    - re-include;
    - anonymize;
    - export (both phone settings);
    - invite-code create and update;
    - category create and update;
    - logout-all.
18. **Dependencies (REQ-S-036).** `npm audit --audit-level=high` in `apps/api` (fix, or note and accept each high/critical); `flutter pub outdated` in `apps/mobile`; Dependabot alerts enabled on the GitHub repo. Record results.

**Phase F — Optional safety-net tests (REQ-N-019, P2)**

19. Only if time allows: add Vitest (+ Supertest candidate) against the app instance with no network port (03 §1.2), a separate test DB and a temp storage folder (06 §8.2). Build them in 06 §8.1 order:
    1. rates fixture;
    2. idempotency;
    3. verify access;
    4. logger redaction;
    5. CSV;
    6. Due boundary.

    Otherwise set REQ-N-019 to `Deferred` with the founder's decision and date.

**Phase G — Close-out**

20. **Spec sync (REQ-O-020).** For every deviation found in TASK-01…10 (collected from each task's §5.6 and Progress log), add or update a row in the affected spec document's "Decisions & Assumptions" table: 01 row 14 (WhatsApp tappability), 02 F2/F3, the 03 rule changes, and so on. Mirror them in the summary's Open Questions.
21. **Final verification layer run (REQ-O-023).**
    - `python3 docs/tasks/check_coverage.py` exits **0**: every active requirement is `Pass`, `Fixed` or `Deferred` with who decided and when.
    - Update the `coverage-verification.md` header (`Verified: 177 / 177 (100%)`, or the new total if REQ IDs were added).
22. **Documentation and board.**
    - Every task file is `Complete` with its §14 checklist ticked.
    - `00-task-summary.md` shows 10/10 (100%), the Verified column is full, the M5 milestone is marked reached, and the Change Log has a close-out row.
    - `python3 docs/tasks/validate_tasks.py docs/tasks/` reports 0 errors.
23. **Commit** `TASK-10: e2e verification and gap closure`, plus a tag for the verified build (e.g. `mobile-v0.x.0+N`, 05 §4.3). Record the hash in §13.

## 7. Acceptance Criteria

### 7.1 Behavioral

**AC-1** — Coverage matrix is 100%
- **Given** TASK-01…09 are complete and the stack is running from a clean reset
- **When** `python3 docs/tasks/check_coverage.py` is run at the end of this task
- **Then** it exits 0, with every active requirement `Pass`, `Fixed` or `Deferred` (with a decision-maker and date), no `Fail`, no `Not Verified`, and every row carrying evidence

**AC-2** — No spec item is unimplemented
- **Given** the inventories in §5.3 and §5.4 (27 routes, 29 endpoints, 20 error codes, 9 events, all 05 §2.2 env vars, 04 §8 seed statuses)
- **When** each is exercised against the running system
- **Then** every item is present and behaves per spec
- **And** any item found without a registry requirement has been added as a new REQ ID, verified, and included in AC-1's count

**AC-3** — No stubs or placeholders remain
- **Given** the codebase after gap closure
- **When** the step 8 sweeps are run
- **Then** there are zero unjustified hits for TODO/FIXME/stub/mock/placeholder, colours outside the theme, string literals in widgets, `console.log` in the API, and hard-coded config values
- **And** every list screen loads real API data

**AC-4** — Full loop on a physical low-end Android phone
- **Given** the debug build on the low-end Android phone over LAN Wi-Fi
- **When** the tester runs the full loop: first launch → invite → report, with the app killed during the CCRS hand-off and the draft restored → admin Due → Send reminder → verify "Not fixed" with photo
- **Then** each step succeeds, exactly one complaint and one verification exist in the DB, and the Rates screen shows the updated H1/H2
- **And** the cleartext exception is limited to the dev machine's address

**AC-5** — Full loop on iOS
- **Given** the debug build on the iOS simulator and on a physical iPhone
- **When** the same loop as AC-4 is run
- **Then** it succeeds on both, with the ATS exception Debug-only, plain-language permission prompts and the `saarthee` scheme registered
- **And** if the iPhone is unavailable, the row is recorded `Blocked`/`Deferred` with reason and decision, never `Pass`

**AC-6** — Real WhatsApp deep link outcome recorded
- **Given** a reminder sent from the operator phone through "Open WhatsApp"
- **When** the citizen taps the verify link in WhatsApp on Android and on iPhone
- **Then** either the app opens on verify entry for that complaint, or (link not tappable) the citizen completes verification via "Answer a follow-up" by pasting the link or code
- **And** the outcome per platform is recorded in the Progress log and in `docs/01-project-overview.md` Decisions row 14

**AC-7** — Accessibility audit passes
- **Given** TalkBack and VoiceOver enabled, the largest system font, grayscale mode and a 320-px-wide device
- **When** the tester runs the report and verify flows and opens every route
- **Then** all controls are announced with labels, photos are described, step progress and errors are announced, focus moves to the error summary on a failed submit, no text is clipped, and statuses are distinguishable without colour

**AC-8** — Performance targets measured
- **Given** the low-end Android phone
- **When** cold start, step transitions, photo compression and photo size are measured
- **Then** the results are recorded against the 02 §8.1 targets, and any miss is either fixed or logged as an S3 note with the measurement

**AC-9** — Privacy and release checklist passes on both phones
- **Given** the 06 §12.3 checklist in §7.2
- **When** it is run on the Android phone and the iPhone
- **Then** every item passes, including:
  - no test phone or verify token in the logs;
  - no phone, coordinates or source on verify screens;
  - no phone column in CSV by default, and an `=` note shown as text;
  - revoked and anonymized links rejected;
  - five bad logins → rate-limit message;
  - no EXIF in stored photos;
  - no cleartext exception in release builds
- **And** there are no open S1/S2 bugs

**AC-10** — Phone exposure confined
- **Given** a test complaint with phone `+91 98765 43210` that has been reminded, verified and exported
- **When** the logs, `events` table, list endpoint, verify endpoints and default CSV are searched
- **Then** the number appears only in `GET /admin/complaints/{id}`, the reminder response and the `includePhone=true` CSV

**AC-11** — Admin audit log complete
- **Given** the admin performs each action type in step 17
- **When** the API log is filtered by level `info` and the action names
- **Then** each action has exactly one line with `adminId` and the target ID (or export type), and no request bodies, phones, notes or tokens

**AC-12** — Dependencies audited
- **Given** the final code
- **When** `npm audit --audit-level=high` and `flutter pub outdated` are run and the GitHub repo settings are checked
- **Then** there are no unaccepted high/critical findings, outdated packages are recorded, and Dependabot alerts are on

**AC-13** — Docs synced and plan closed
- **Given** all deviations collected from every task's §5.6 and Progress log
- **When** close-out is done
- **Then** each deviation appears in the affected spec document's Decisions & Assumptions table
- **And** all 10 task files are `Complete`, the summary shows 10/10 (100%) with M5 reached, and the validator reports 0 errors

**AC-14** — Optional safety-net tests (P2)
- **Given** time is available after AC-1…AC-13
- **When** the Vitest suite from 06 §8.1 is run
- **Then** all included tests pass
- **Otherwise**, REQ-N-019 is `Deferred` in the matrix with the founder's decision and date

**AC → Requirement traceability**

| AC | Requirements |
|---|---|
| AC-1, AC-2, AC-3 | REQ-O-023 |
| AC-4, AC-5 | REQ-O-014 |
| AC-6 | REQ-O-015 |
| AC-7 | REQ-N-018 |
| AC-8 | REQ-N-017 |
| AC-9 | REQ-O-016 |
| AC-10 | REQ-S-026 |
| AC-11 | REQ-S-027 |
| AC-12 | REQ-S-036 |
| AC-13 | REQ-O-020 |
| AC-14 | REQ-N-019 |

### 7.2 Non-Functional Checklist

06 §12.3 release checklist (tick per device in the Progress log; tick here when both pass):

**Builds and static checks**
- [ ] Backend type-check and lint pass; `dart analyze` passes
- [ ] `npm audit` shows no high or critical issues (or each one is noted and accepted)
- [ ] Release build has **no** plain-HTTP exception and no debug flags (inspect the merged Android manifest/network-security config and iOS Release Info.plist)

**Core flows (06 §10.1)**
- [ ] All P0 flows pass on the low-end Android phone and on an iPhone: first launch, report, report under poor conditions, reminder, verify, admin data
- [ ] P1 flows pass: anonymize (phone gone, photos gone, old verify link rejected); accessibility
- [ ] Draft survives: app killed during the CCRS hand-off, then reopened
- [ ] Retry after a network drop creates **one** complaint, not two (check the admin list)

**Correct numbers**
- [ ] With the seed dataset, Rates matches a hand count for at least the "trusted" row: complaints, reminded, verified, H1, not fixed, H2 (compare with `SELECT * FROM pilot_rates_v`)
- [ ] Excluded complaints disappear from the rates; re-including restores them

**Privacy and security**
- [ ] Search the API log file for a test phone number and a verify token: `rg -n "9876543210|<raw-token>" <log>` → **no matches**
- [ ] Verify screens show no phone, coordinates or source
- [ ] CSV without "include phone" has no phone column; a note starting with `=` appears as text in Excel or Sheets
- [ ] A revoked or anonymized complaint's verify link is rejected (410 `VERIFY_TOKEN_REVOKED`)
- [ ] Wrong admin password five times leads to a rate-limit message
- [ ] A downloaded stored photo has no location or device metadata: `exiftool <photo>` shows no GPS/Make/Model/DateTimeOriginal

**Task-specific**
- [ ] Every route in §5.4 shows its loading/empty/error/offline/unauthorized states where applicable
- [ ] No colours outside the theme, no string literals in widgets, no `console.log`, no hard-coded config (step 8 sweeps clean)
- [ ] Every fix in this task is committed with a `TASK-10:` message and referenced by hash in the coverage matrix

## 8. Validation & Testing

| ID | Level | What to test | Proves |
|---|---|---|---|
| S-10-01 | Static | `npm run typecheck && npm run lint` (api); `dart format --set-exit-if-changed . && dart analyze` (mobile); CI green on `main` | AC-3, AC-9 |
| M-10-01 | Verification layer | `python3 docs/tasks/check_coverage.py` → exit 0; output pasted in Progress log | AC-1 |
| M-10-02 | Verification layer | `python3 docs/tasks/validate_tasks.py docs/tasks/` → 0 errors | AC-13 |
| M-10-03 | App manual | Route sweep: all 27 routes on Android + iOS, states checked, ticked in Progress log | AC-2 |
| M-10-04 | API manual | Endpoint sweep: all 29 rows of §5.3 with curl, including key error codes; all 20 error codes produced | AC-2 |
| M-10-05 | DB manual | `SELECT name, properties FROM events GROUP BY 1,2` → all 9 events present with only allowed properties; seed status query covers every status | AC-2 |
| M-10-06 | Config manual | Remove each required API env var in turn → startup fails with a clear message; `.env.example` lists all 05 §2.2 vars; each run configuration defines all dart-defines | AC-2 |
| M-10-07 | Code sweep | Step 8 `rg` commands → zero unjustified hits | AC-3 |
| M-10-08 | Device manual | Full loop on low-end Android phone over LAN (step 10) | AC-4 |
| M-10-09 | Device manual | Full loop on iOS simulator and iPhone (step 11) | AC-5 |
| M-10-10 | Device manual | Real WhatsApp link on both platforms; fallback code entry; `deep_link_failed` row present | AC-6 |
| M-10-11 | Accessibility manual | TalkBack + VoiceOver, largest font, grayscale, 320 px, reduced motion (step 14) | AC-7 |
| M-10-12 | Performance manual | Stopwatch/screen-recording measurements (step 13); `SELECT avg(byte_size) FROM photos` | AC-8 |
| M-10-13 | Release checklist | Full §7.2 checklist on both phones, with build version | AC-9 |
| M-10-14 | Privacy manual | Step 16 log/events/list/verify/CSV searches for the test phone | AC-10 |
| M-10-15 | Log manual | Step 17 one-line-per-admin-action check | AC-11 |
| M-10-16 | Dependency manual | `npm audit --audit-level=high`, `flutter pub outdated`, GitHub Dependabot setting | AC-12 |
| M-10-17 | Docs manual | Every deviation in spec Decisions tables; all task files Complete; summary 100% | AC-13 |
| O-10-01 | Optional automated | Vitest + Supertest, 06 §8.1 #1–#6 in order (rates, idempotency, verify access, redaction, CSV, due boundary). **Optional, P2** | AC-14 |

Bug notes use the 06 §12.2 format: build version, device and OS, steps, expected, actual, screenshot with phone numbers blurred.

## 9. Deliverables

- `docs/tasks/coverage-verification.md` at 100%, with evidence on every row.
- All gap fixes committed (`TASK-10: …`), with hashes in the matrix.
- Device verification records: Android phone model and OS, iPhone model and iOS version, build version, WhatsApp tappability result, performance measurements, accessibility findings — all in §13.
- The completed 06 §12.3 checklist, per device.
- Updated "Decisions & Assumptions" tables in the affected spec documents (01–07).
- All task files `Complete`; `00-task-summary.md` at 10/10 (100%) with M5 reached; registry updated with any new REQ IDs.
- Optional: `apps/api/test/` Vitest safety-net suite.
- A tagged verified build.

## 10. Files Expected to Change

This is a prediction, not a constraint. The exact fixes depend on what the audit finds.

| Path | Change |
|---|---|
| `apps/api/src/**` | Modified (gap fixes) |
| `apps/mobile/lib/**` | Modified (gap fixes, string/colour cleanup, accessibility fixes) |
| `apps/mobile/android/app/src/debug/`, `apps/mobile/ios/Runner/Info.plist`, Xcode build configs | Modified (cleartext/ATS scoping, permission strings, if gaps) |
| `apps/api/test/` | New (optional Vitest suite) |
| `apps/api/package.json`, `apps/mobile/pubspec.yaml` | Modified (dependency updates, optional test deps) |
| `.github/` (Dependabot config, if used) | New/Modified |
| `docs/01-…07-*.md` (Decisions & Assumptions tables) | Modified |
| `docs/tasks/coverage-verification.md`, `requirements-registry.md`, `00-task-summary.md`, all `TASK-*.md` | Modified |

## 11. Related Documentation

- `docs/06-security-testing.md §10.1`: critical user flows (P0/P1) to run on devices.
- `docs/06-security-testing.md §10.2`: E2E environment rules (devices, trusted Wi-Fi, no real data, deep-link testing).
- `docs/06-security-testing.md §12.2–12.3`: bug severity and the release checklist reproduced in §7.2.
- `docs/06-security-testing.md §8.1–8.2`: optional safety-net tests and their test-data strategy.
- `docs/02-frontend-spec.md §2.3`: accessibility requirements.
- `docs/02-frontend-spec.md §3.1`: route inventory.
- `docs/02-frontend-spec.md §8.1`: performance targets.
- `docs/03-backend-spec.md §2.2`: endpoint inventory.
- `docs/03-backend-spec.md §9.1`: error codes.
- `docs/03-backend-spec.md §11`: events.
- `docs/05-devops-infrastructure.md §2.2`: env vars.
- `docs/05-devops-infrastructure.md §4.5–4.6`: device installs, cleartext/ATS, URL scheme.
- `docs/04-database-design.md §8`: seed coverage.
- `docs/04-database-design.md §3.9`: H1/H2 definitions for the hand count.
- `docs/01-project-overview.md §7.1` and Decisions row 14: WhatsApp custom-scheme tappability.
- `docs/07-implementation-roadmap.md §3 Stage E` and `§7`: device steps and definition of done.

## 12. Risks & Considerations

| Risk | Impact | Mitigation |
|---|---|---|
| iOS signing or Mac unavailable | iPhone verification blocked | Android first; iOS simulator still verified; record iPhone rows `Blocked` with reason in the summary (never `Pass`); founder decides whether to defer |
| WhatsApp does not make `saarthee://` links tappable | Verify loop depends on the fallback | Manual code entry (02 §4.12) verified as the working path; the reminder template already includes the fallback line; outcome recorded in 01 Decisions row 14 |
| Gaps larger than expected | Task overruns, or features silently absorbed | Log new REQ IDs; reopen the owning task (`In Progress`) for whole-feature gaps and record it in the summary Change Log; small fixes stay here as `Fixed` |
| Low-end Android phone model still not chosen (02 F3) | Performance unmeasured | Choose one before starting Phase C; if impossible, record REQ-N-017 as `Blocked` |
| Accessibility fixes ripple through shared components | Regressions in other screens | Fix in shared components (TASK-03 set); re-run the route sweep after each component change |
| Evidence contains personal data | Privacy breach in docs | Only invented test numbers; blur screenshots; never paste raw tokens into docs (use `<raw-token>` in commands) |
| Real citizen data used "just to test" | Breach of 06 §5.1 | Explicitly forbidden; seed and team test data only |

## 13. Progress Status

**Current status:** In Review
**Progress:** 70%

| Date | Progress | Commit |
|---|---|---|
| 2026-10-03 | Emulator-scoped E2E: 06 §10.1 flows run on Android emulator (first launch valid/invalid/skip, report incl. CCRS hand-off + kill + camera + GPS, reminder, verify via adb deep link and manual code, admin detail/exclude/re-include/export screens, session ended, offline banner); privacy-checks.mjs 14/14 (log grep phone+token, CSV w/o phone, revoked link 410, 5 bad logins 429, stored photo no EXIF); stub/colour/string sweeps clean; coverage matrix 151 Pass / 26 Deferred; S2 fix faab1b2 (UnmountedRefException after 'Use this photo'); demo:reset + DEMO.md. Unfinished (Deferred — needs physical device): low-end phone perf, TalkBack/VoiceOver, iPhone, real WhatsApp, release checklist on phones; Vitest (P2 cut). S3 known issues: debug cold start ~15 s on loaded emulator (use profile build), image_picker retrieveLostData not handled, 'Use this photo' below the fold. | b55b47a, faab1b2 |

## 14. Completion Checklist

- [ ] All implementation steps complete
- [ ] All behavioral acceptance criteria verified in the running application
- [ ] Non-functional checklist fully ticked (06 §12.3 passes on both phones)
- [ ] Static checks pass and every AC verified by the manual checks in §8 (no automated tests in v1 — 06 §7.1)
- [ ] Frontend and backend integrated end to end (no mocked data left in place)
- [ ] Error, loading, empty, and unauthorized states verified on every route
- [ ] Code reviewed against the patterns established in earlier tasks
- [ ] Assumptions documented and, where possible, confirmed
- [ ] No open S1/S2 bugs
- [ ] Every spec deviation recorded in the affected document's Decisions & Assumptions table
- [ ] Coverage matrix rows for this task's requirements set to Pass with evidence (`check_coverage.py --task TASK-10` shows 0 unverified)
- [ ] `check_coverage.py` (all tasks) exits 0 — verification layer at 100%
- [ ] Task file progress log and status updated
- [ ] `00-task-summary.md` updated (10/10, 100%, M5 reached)
- [ ] Committed as `TASK-10: …`
- [ ] Validator passes
