# TASK-06: Issue Lifecycle, Verification and Escalation

| Field | Value |
|---|---|
| Task ID | TASK-06 |
| Status | In Review |
| Priority | P0 |
| Size | L |
| Depends On | TASK-05 |
| Blocks | TASK-07, TASK-11 |
| Requirement IDs | REQ-F-020, REQ-F-021, REQ-F-022, REQ-F-023, REQ-F-024, REQ-F-025, REQ-F-026, REQ-F-027, REQ-F-063 |
| Primary Spec Refs | Spec §3 (roles), §5 (lifecycle, verification, reopen window, SLA, escalation, CCRS reminder), §6 (`issues`, `issue_events`, `issue_verifications`, `issue_photos`), §7 (status, verifications, escalations, events; rate limits), §9 (issue-update notifications), §11 (privacy); DS §2 (status colours), §4 (shape, Rounded icons), §5 (status chip, status timeline, toast, buttons), §6 (Motion), §7 (accessibility), §8 (verify flow) |
| Last Updated | 2026-10-04 |

## 1. Objective

Make reported issues move to a real, checkable fix. The server owns one state machine (Spec §5) that decides who may change an issue's status, writes every change to `issue_events`, and never lets the app bypass it. A reporter, a ward representative or a moderator can mark an issue fixed, optionally with an "after" photo; neighbours then confirm with a photo taken within 100 m, and the rules turn that into Verified or Reopened. Issues past their Saarthee target are flagged and the citizen can escalate with a pre-filled, evidence-linked message up the ladder. Reporters and followers are told about every change by push and inbox. In the app every status change is visible and announced: the status chip cross-fades to its new colour, icon and word, the new timeline step expands from its dot, TalkBack says "Status changed to Fixed", and a neighbour's "Yes, it's fixed" ends in a toast with a drawn check while the chip moves Fixed → Verified.

## 2. Scope

### In Scope
- Lifecycle service `transition()` with the transition table and role rules (§5.3), optimistic concurrency, idempotent actions; used by every status change in the codebase (TASK-05 CCRS link refactored onto it; TASK-10/11 call it).
- `POST /issues/{id}/status` (acknowledge, in progress, mark fixed with optional after photo).
- `POST /issues/{id}/verifications` with photo, distance check against `VERIFY_RADIUS_M`, the Fixed/Not-fixed rules, per-day uniqueness, quota 20/day (TASK-05 helper).
- Reopen window (7 days, configurable) and derived "Fixed (not verified)" display status.
- SLA: `sla_due_at` reset on reopen, `isOverdue` derivation, hourly overdue job with notification.
- Escalation message generator `POST /issues/{id}/escalations` for four levels (corporators via relay, zone office, Deputy Municipal Commissioner, Municipal Commissioner) + `escalation_contacts` table.
- CCRS "AMC closed it" (`POST /issues/{id}/ccrs/closed`) with 24 h reopen reminder (P1).
- `GET /issues/{id}/events` (timeline, privacy-safe actor labels).
- Notifications to reporter and followers via TASK-04 push service + inbox rows.
- Job runner (`src/jobs`) with single-instance lock.
- App screens: Verify (`/issues/:id/verify`), Mark fixed (`/issues/:id/mark-fixed`), Escalate (`/issues/:id/escalate`), "AMC closed it" sheet and 24 h banner, reusable `IssueStatusActions` and `issueEventsProvider`.
- Retire v1 verify routes and `/verify/*` API (410), reusing v1 verification photo/distance code.
- Lifecycle motion (REQ-F-063, DS §6 catalogue rows owned by TASK-06): `AnimatedStatusChip` (cross-fade of colour, icon and word, `short`), animated insertion of a new `StatusTimeline` step that expands from its dot, the verify Send button → in-button progress → toast with `MotionCheck`, chip Fixed → Verified, and a TalkBack announcement of every status change via `SemanticsService.announce`. Built only from TASK-03's `SaartheeMotion` tokens and motion widgets, with a reduced-motion variant; TASK-07's detail screen and TASK-10/11 consoles reuse these widgets.

### Out of Scope
- Issue detail screen layout and the buttons that open these screens — TASK-07.
- Reject, merge, recategorise, hide (staff endpoints) — TASK-10 (they call `transition()`).
- Representative claim, dashboard and the representative UI — TASK-11; this task only enforces ward scope for the `representative` role.
- The relay message send itself — TASK-09 (`POST /representatives/{id}/messages`); escalation only prepares text and targets.
- Public evidence web page `/i/{id}` — TASK-07 (this task only builds the URL).
- Alert notifications and the inbox UI — TASK-08.

## 3. Prerequisites

- TASK-05 complete: issues, photos (owner + blur), quota helper, `issue_events` written on create, reporter auto-follow, CCRS link.
- TASK-01 tables: `issue_verifications` (UNIQUE `(issue_id, user_id, day)`), `representative_areas`, `notifications`; Vitest harness.
- TASK-02: `wards.office_address`, `office_phone`, zone codes.
- TASK-03: Neem `StatusChip`, `StatusTimeline`, toast, `PrimaryButton` with in-button progress; motion foundation (`SaartheeMotion` tokens in `lib/core/theme/motion.dart`, `animations` + `flutter_animate`, press-scale wrapper, haptics helper with a test fake, `MotionCheck`, reduced-motion handling via `MediaQuery.disableAnimations` + in-app Animations switch, static test forbidding `Duration(` in `lib/features/**`).
- TASK-04: `requireUser`, roles on `users.role`, push service `notify(recipients, message)` that writes `notifications` and sends FCM to the user's tokens.
- Env: `VERIFY_RADIUS_M=100`, `VERIFY_MAX_ACCURACY_M=50`, `REOPEN_WINDOW_DAYS=7`, `NOT_FIXED_THRESHOLD=2`, `CCRS_REOPEN_HOURS=24`, `CCRS_REMINDER_AFTER_HOURS=20`, `JOBS_ENABLED=true|false`, `PUBLIC_WEB_BASE_URL` (e.g. `https://saarthee.app`), `QUOTA_STATUS_CHANGES_PER_DAY=30`, `QUOTA_ESCALATIONS_PER_DAY=10`.

## 4. Dependencies

| Task | Why it is required |
|---|---|
| TASK-05 | Issues must exist with photos, ward, SLA date, opening event, reporter follow, quota helper and CCRS link |

## 5. Technical Context

### 5.1 Requirements Covered

| Req ID | Requirement | Source |
|---|---|---|
| REQ-F-020 | Issue status transitions enforced server-side by role (§5 state machine); every change appended to `issue_events` | Spec §5 |
| REQ-F-021 | Marked-fixed by reporter, representative or moderator, optionally with an after photo | Spec §5 |
| REQ-F-022 | Verification: citizen answers Fixed/Not fixed with a photo within `VERIFY_RADIUS_M` (100 m); rules move the issue to verified or reopened | Spec §5 |
| REQ-F-023 | Reopen window of 7 days after marked-fixed; after that the issue shows "Fixed (not verified)" | Spec §5 |
| REQ-F-024 | SLA due date per category; overdue issues flagged in lists and detail | Spec §5 |
| REQ-F-025 | Escalation ladder: pre-filled message to corporators (relay), zone office, deputy commissioner, commissioner with evidence link | Spec §5 |
| REQ-F-026 | CCRS 24-hour reopen reminder when the citizen marks "AMC closed it" | Spec §5 |
| REQ-F-027 | Followers and reporter get push + inbox notifications on status changes and verification requests | Spec §9 |
| REQ-F-063 | Lifecycle motion per DS §6: status chip cross-fades colour/icon/word, new timeline step expands from its dot, "Yes, fixed" button → progress → toast with drawn check, TalkBack announces the new status | DS §6 |

### 5.2 Data Contracts

Migration `<ts>_v2_lifecycle` (after TASK-05's):
- `issues`: add `marked_fixed_at TIMESTAMPTZ NULL`, `verified_at NULL`, `reopened_count INT NOT NULL DEFAULT 0`, `overdue_notified_at NULL`, `ccrs_closed_at NULL`, `ccrs_reminder_sent_at NULL`, `status_version INT NOT NULL DEFAULT 0` (optimistic lock); index `(status, sla_due_at)`, partial index `(ccrs_closed_at) WHERE ccrs_reminder_sent_at IS NULL`.
- `issue_event_type` enum: add `ccrs_closed`, `verification`, `system` (if missing).
- `photo_purpose` enum: add `after` (`verification` exists from v1).
- `issue_events`: add `client_action_id UUID NULL UNIQUE` (idempotent actions), `meta JSONB NULL` (e.g. `{distanceM, answer, level}`; never PII).
- New `escalation_contacts`: `id`, `level` (`zone_office`/`deputy_commissioner`/`commissioner`), `zone_id NULL` (NULL = city-wide), `title_en`, `title_gu`, `email NULL`, `phone NULL`, `source_url NOT NULL`, `last_verified_at NOT NULL`, `is_active`; UNIQUE `(level, zone_id)`. Dev seed: fictional `@example.org` contacts; pilot data entered from AMC's published lists by staff (TASK-10/TASK-14).
- `issue_verifications` insert: `issue_id`, `user_id`, `answer`, `photo_id` (`purpose=verification`, owned by the user), `lat/lng`, `gps_accuracy_m`, `distance_m` (PostGIS `ST_Distance` on geography; v1 `haversineM` kept as the unit-tested fallback in `src/lib/geo/distance.ts`), `client_submission_id UNIQUE`, `created_at`; `day` = IST date.

Status sets: **open** = `reported, sent, acknowledged, in_progress, reopened`; **terminal** = `rejected, merged`. Derived fields returned by every issue serializer (`src/modules/issues/derive.ts`):
- `isOverdue` = status ∈ open ∧ `now() > sla_due_at`.
- `verifyWindowClosesAt` = `marked_fixed_at + REOPEN_WINDOW_DAYS` when status ∈ {`marked_fixed`, `verified`}.
- `displayStatus` = `fixed_unverified` when status = `marked_fixed` ∧ window closed; otherwise the status.

### 5.3 API Contracts

Transition table (`src/modules/lifecycle/transitions.ts`; anything else → 409 `INVALID_TRANSITION`):

| From | To | Allowed actors | Extra rule |
|---|---|---|---|
| reported | sent | reporter (CCRS link, escalation), system | channel in `note` |
| reported, sent, reopened | acknowledged | representative (own ward), moderator, admin; reporter with CCRS linked ("AMC acknowledged") | |
| reported, sent, acknowledged, reopened | in_progress | representative (own ward), moderator, admin | |
| reported, sent, acknowledged, in_progress, reopened | marked_fixed | reporter, representative (own ward), moderator, admin | optional `photoId` (`purpose=after`, ≤ 3) |
| marked_fixed | verified | system (verification rule) | |
| marked_fixed, verified | reopened | system (verification rule) | within window |
| any open, marked_fixed | rejected / merged | moderator, admin (TASK-10) | `note` required for rejected |

Role resolution: `actorRole` = `reporter` when `user.id = issue.reporter_id`, else `user.role`. Representative ward scope: `issue.ward_id ∈ representative_areas.ward_id` of the representative linked to `users.id` (verified only); otherwise 403 `OUT_OF_WARD`. A plain citizen who is not the reporter gets 403 `FORBIDDEN_ROLE`. Suspended users 403 `ACCOUNT_SUSPENDED`.

`transition(issueId, to, actor, {note, photoIds, clientActionId, expectedStatus, system})` in one transaction: `SELECT … FOR UPDATE` → idempotency by `client_action_id` (repeat returns the original event) → `expectedStatus` mismatch → 409 `STALE_STATUS` with current status → table + role check → update `status`, `status_changed_at`, `status_version+1`, timestamps (`marked_fixed_at`, `verified_at`; on `reopened`: `reopened_count+1`, `sla_due_at = now() + sla_days`, `overdue_notified_at = NULL`) → attach after photos (`issue_photos kind=after`) → insert `issue_events` → enqueue notification fan-out after commit.

| Method | Path | Auth | Request | Response | Errors | Rate limit |
|---|---|---|---|---|---|---|
| POST | `/api/v1/issues/{id}/status` | Signed in | `{to: acknowledged\|in_progress\|marked_fixed, note? ≤500, photoIds?[] ≤3, clientActionId (uuid), expectedStatus}` | 200 `{issue (derived fields), event}` | 400, 401, 403 `FORBIDDEN_ROLE`/`OUT_OF_WARD`/`ACCOUNT_SUSPENDED`, 404, 409 `INVALID_TRANSITION`/`STALE_STATUS`, 422 `PHOTO_UNUSABLE`, 429 | `QUOTA_STATUS_CHANGES_PER_DAY` for citizens |
| POST | `/api/v1/photos` | Signed in | `purpose=after\|verification`, `issueId` | 201 `{photoId}` | as TASK-05 | as TASK-05 |
| POST | `/api/v1/issues/{id}/verifications` | Citizen | `{clientSubmissionId, answer: fixed\|not_fixed, photoId, latitude, longitude, gpsAccuracyM, deviceCapturedAt, note? ≤500}` | 201/200 `{verificationId, distanceM, issue:{status, displayStatus}}` | 400, 401, 404, 409 `VERIFY_NOT_OPEN`/`ALREADY_ANSWERED_TODAY`, 422 `TOO_FAR_FROM_ISSUE` (`details:[{field:'location', distanceM, radiusM}]`)/`LOCATION_TOO_INACCURATE`/`PHOTO_UNUSABLE`, 429 | quota `verifications` 20/day |
| GET | `/api/v1/issues/{id}/events?cursor&limit≤50` | None (hidden issue: reporter/staff) | — | `{items:[{id, type, fromStatus, toStatus, actorLabel:{kind, wardNameEn, wardNameGu, name?}, note?, photoUrls[], meta, createdAt}], nextCursor}` oldest first | 404 | 120/IP/min |
| POST | `/api/v1/issues/{id}/escalations` | Citizen (reporter or follower) | `{level: corporators\|zone_office\|deputy_commissioner\|commissioner, language: gu\|en}` | 200 `{level, recommendedLevel, subject, message, evidenceUrl, targets:[{kind: relay\|email\|phone, representativeId?, label, email?, phone?, sourceUrl?}], independenceNote}` | 403, 404, 409 `ISSUE_NOT_OPEN`, 429 | `QUOTA_ESCALATIONS_PER_DAY` |
| POST | `/api/v1/issues/{id}/ccrs/closed` | Reporter | `{closedAt? (≤ now, ≥ ccrs_filed_at)}` | 200 `{ccrsClosedAt, reopenDeadline}` | 403, 404, 409 `CCRS_NOT_LINKED` | 10/user/day |
| ANY | `/api/v1/verify/*` (v1) | — | — | 410 `ENDPOINT_RETIRED` | — | — |

Verification rules (`lifecycle/verification.service.ts`), all in one transaction with the row lock:
1. Accept only when status ∈ {`marked_fixed`, `verified`} and `now() ≤ verifyWindowClosesAt`; else 409 `VERIFY_NOT_OPEN`.
2. Photo: `purpose=verification`, uploaded by this user for this issue, unattached, ≤ 24 h; `gpsAccuracyM ≤ VERIFY_MAX_ACCURACY_M` else 422 `LOCATION_TOO_INACCURATE`; `distance ≤ VERIFY_RADIUS_M` else 422 `TOO_FAR_FROM_ISSUE`. Nothing is stored on rejection.
3. Insert the verification + `issue_events(type=verification, meta {answer, distanceM})` (no status change yet).
4. `fixed` while `marked_fixed` → `transition(→ verified, system)`.
5. `not_fixed` by the reporter → `transition(→ reopened, system, note "Reporter says it is not fixed")`.
6. `not_fixed` by others: count distinct users with `not_fixed` since `marked_fixed_at`; ≥ `NOT_FIXED_THRESHOLD` → `reopened`. One `fixed` does not cancel two `not_fixed`; the rule is evaluated after each answer, and `reopened` wins over `verified`.
7. Repeat `clientSubmissionId` → 200 with the original. Second answer same user same IST day → 409 `ALREADY_ANSWERED_TODAY`.

SLA overdue job `sla-overdue` (hourly): `status ∈ open AND sla_due_at < now() AND overdue_notified_at IS NULL` → notify reporter + followers, set `overdue_notified_at`, append `issue_events(type=system, note='overdue')`.

Escalation generator (`escalation/escalation.service.ts`): `recommendedLevel` = `corporators` until the first escalation; next level once the previous level's event is ≥ 7 days old and the issue is still open and overdue. Text template (ARB-like server templates `escalation.<level>.<lang>`), e.g. English corporators:
> Subject: Overdue civic issue in ward <Ward> — <Category>
> Dear Corporator, a <category> problem reported on <date> at <evidenceUrl> is still <status> after <n> days (Saarthee target: <slaDays> days). <meTooCount> residents are affected. Please arrange for it to be fixed. — A resident of <Ward>, sent via Saarthee (independent citizen app, not an official AMC complaint).

Targets: `corporators` → one `relay` target per corporator from `representative_areas` (empty list when none — the app falls back to Copy/Share); `zone_office` → `wards.office_phone`/`office_address` and `escalation_contacts(zone_office, zone)`; `deputy_commissioner` → contact for the zone; `commissioner` → city-wide contact. `evidenceUrl` = `${PUBLIC_WEB_BASE_URL}/i/<issueId>`. Logs `issue_events(type=escalated, meta {level})`; if status is `reported`, also `transition(→ sent, note 'escalated:<level>')`.

CCRS closed (P1): sets `ccrs_closed_at`, event `ccrs_closed`; no status change. Job `ccrs-reopen-reminder` (every 15 min): `ccrs_closed_at + CCRS_REMINDER_AFTER_HOURS ≤ now()` ∧ reminder not sent ∧ status ∉ {verified} → push "4 hours left to reopen on AMC" to the reporter, set `ccrs_reminder_sent_at`.

Notification fan-out (`lifecycle/notify.ts`, after commit, via TASK-04 `notify()`; kind `issue_update`, `ref_id = issueId`; recipients = followers (incl. reporter) minus the actor; in the recipient's language; quiet hours 22:00–07:00 deferred to 07:00 IST through the push service's `notBefore`):

| Trigger | Title (en) | Body (en) |
|---|---|---|
| → acknowledged | "Your issue was acknowledged" | "<Category> in <Ward> is now acknowledged." |
| → in_progress | "Work has started" | "<Category> in <Ward> is in progress." |
| → marked_fixed | "Is it fixed? Help check" | "<Category> in <Ward> was marked fixed. If you're nearby, take a photo to confirm." |
| → verified | "Fix verified" | "Neighbours confirmed <Category> in <Ward> is fixed." |
| → reopened | "Issue reopened" | "<Category> in <Ward> was reopened — it's not fixed yet." |
| overdue | "Past its target date" | "<Category> in <Ward> is past Saarthee's <n>-day target. You can escalate it." |
| CCRS reminder | "Reopen on AMC soon" | "AMC closed your complaint. You can reopen it on AMC's site only until <time>." |

Push data payload `{kind:'issue_update', issueId, route:'/issues/<id>'}` (verification request route `/issues/<id>/verify`). No titles/bodies containing reporter identity.

New `AppError` codes: `INVALID_TRANSITION` 409, `STALE_STATUS` 409, `FORBIDDEN_ROLE` 403, `OUT_OF_WARD` 403, `VERIFY_NOT_OPEN` 409, `ALREADY_ANSWERED_TODAY` 409, `TOO_FAR_FROM_ISSUE` 422, `LOCATION_TOO_INACCURATE` 422, `CCRS_NOT_LINKED` 409.

### 5.4 UI Surfaces & States

| Route / widget | Content | States |
|---|---|---|
| `/issues/:id/verify` (Step 1 of 2) | Title "Is it fixed?"; issue photo before/after side by side; buttons "Yes, it's fixed" / "Still not fixed" | window closed → "This issue can no longer be checked." ; signed out → sign-in then back |
| `/issues/:id/verify/photo` (Step 2 of 2) | "Take a photo at the spot"; live distance "You're about 35 m from the problem."; optional note "Anything to add? (optional)"; pinned 56 dp primary "Send" (`primary`, never `sunrise`) that turns into an in-button progress bar while sending | too far → "You need to be within 100 m of the problem to verify. You're about 240 m away." (Send disabled); inaccurate GPS → "Location is approximate. Move into the open and try again."; upload failed → "Retry upload"; offline → draft kept, sends on reconnect; already answered → "You've already answered today. Thank you." |
| Verify result (toast, replaces the v2.0 `/verify/done` screen per DS §8) | After Send succeeds the verify routes pop back to the issue (TASK-07 detail, or Home when opened from a push with no detail in the stack) and a DS §5 toast (`primaryDark`, radius 18, 4 s) slides up with a drawn check: "Thanks for checking. It's now Verified." / "Thanks for checking. It's been reopened." / "Thanks for checking. Your answer is recorded." | Toast text is also announced by TalkBack; failure keeps the user on step 2 with the error |
| `/issues/:id/mark-fixed` | Title "Mark as fixed"; "Add an after photo (optional)" (camera, ≤ 3, blur as TASK-05); "Note (optional)"; primary "Mark as fixed"; helper "Neighbours will be asked to confirm with a photo." | `STALE_STATUS` → "This issue changed while you were here." + reload; forbidden → "You can't change this issue." |
| `/issues/:id/escalate` | Title "Escalate this issue"; ladder list of 4 levels (Corporators, Zone office, Deputy Municipal Commissioner, Municipal Commissioner) with the recommended one tagged "Suggested"; message preview (editable copy only); actions per target: "Message corporator" (opens TASK-09 relay with text and `issueId`), "Email zone office", "Call zone office", "Copy message", "Share"; note "Saarthee prepares this message for you. It is not an official complaint." + independence line | no corporator data → only Copy/Share; loading skeleton; error + "Try again" |
| `CcrsClosedSheet` | "Did AMC close your complaint?" → "Yes, AMC closed it" → banner "AMC says it's closed. If it isn't fixed, reopen it on AMC's site before <time> (24 hours)." + "Open AMC site", "It's fixed — verify" | not linked → hidden |
| `IssueStatusActions` | Role-aware buttons "Acknowledge", "Start work", "Mark as fixed" for staff/representatives (used in TASK-07 detail, TASK-10/11 consoles) | in-flight disabled; errors as above |
| `issueEventsProvider` | Paged timeline items mapped to DS §5 `StatusTimeline` (TASK-03 component); actor text "A resident of Paldi", "Ward corporator <name>", "Saarthee moderator", "Saarthee" (system) | skeleton; error retry |

ARB keys under `verify.*`, `markFixed.*`, `escalate.*`, `ccrsClosed.*`, `timeline.actor.*`, `notification.issue.*`, `status.announce` ("Status changed to {status}" / "સ્થિતિ બદલાઈ: {status}"), `error.<CODE>`; gu strings marked for native review.

Lifecycle motion (REQ-F-063, DS §6). Widgets in `lib/features/issue_actions/presentation/motion/` (exported for TASK-07/10/11); every duration and curve from `SaartheeMotion`; no `Duration(` literal in `lib/features/issue_actions/**`.

| Moment | Motion (normal) | Reduced motion (`MediaQuery.disableAnimations` or in-app Animations off) | Announcement / haptic |
|---|---|---|---|
| Status changes while the chip is on screen (own action, refresh, foreground push) | `AnimatedStatusChip` cross-fades tint, text colour, icon and word together over `short` (old and new chip stacked in a fixed-size pill, opacity only); no animation on first build | Swaps instantly | `SemanticsService.announce("Status changed to <word>")` in the app language, once per change, not on first build |
| New timeline event arrives | The new `StatusTimeline` step grows from its 14 dp dot: the dot scales in (`springIn`), then the row's height expands top-down inside a `ClipRect` (`medium`, the DS §6 clipped exception) while its text fades in; earlier steps do not move other than being pushed down by the expansion | Step present on the next frame | Covered by the chip announcement (no second announcement) |
| Verify Send ("Yes, it's fixed" / "Still not fixed" path) | Send's label fades to an in-button linear progress bar (`short`), button disabled; on success the routes pop (`medium` shared-axis back), then the toast slides up with `springIn` and its leading `MotionCheck` draws (`drawCheck`); on the issue the chip cross-fades Fixed → Verified (or → Reopened) and the new step expands | Progress shown statically; toast and chip appear instantly | Light haptic on Send press (TASK-03 primary press); toast text announced |
| Mark fixed / staff actions (`IssueStatusActions`) | Same in-button progress; chip and timeline animate as above | Instant | Chip announcement |


### 5.5 Permissions & Roles

| Action | Visitor | Citizen (not reporter) | Reporter | Representative | Moderator | Admin |
|---|---|---|---|---|---|---|
| Read events of public issue | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Acknowledge / in progress | ❌ | ❌ | Acknowledge only with CCRS linked | Own wards | ✅ | ✅ |
| Mark fixed | ❌ | ❌ | ✅ | Own wards | ✅ | ✅ |
| Verify (Fixed / Not fixed) | ❌ | ✅ | ✅ | ✅ (as a citizen) | ✅ | ✅ |
| Escalate | ❌ | Followers only | ✅ | ❌ | ❌ | ❌ |
| AMC closed it | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ |
| Reject / merge (TASK-10) | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ |

Staff actions through `transition()` are recorded in the TASK-10 audit log when called from `/staff/*`.

### 5.6 Assumptions

- ASSUMPTION: Verifications stay open while status is `verified` and the 7-day window runs, so a reporter's "Still not fixed" can reopen a quickly verified issue — spec says reporter's Not fixed → reopened without excluding `verified`.
- ASSUMPTION: "Two Not fixed" means two distinct non-reporter users since the latest `marked_fixed_at`; a single Fixed does not cancel them.
- ASSUMPTION: GPS accuracy worse than 50 m rejects a verification (`LOCATION_TOO_INACCURATE`); the 100 m radius is measured from the reported fix without adding accuracy slack — conservative against remote verifying.
- ASSUMPTION: "Fixed (not verified)" is derived at read time, not a stored status; no job is needed for it.
- ASSUMPTION: Reopen restarts the SLA clock (`sla_due_at = now() + sla_days`) and clears `overdue_notified_at`.
- ASSUMPTION: "AMC closed it" does not change the Saarthee status; it prompts verification and the 24 h reminder at +20 h.
- ASSUMPTION: DMC/Commissioner contacts live in `escalation_contacts` with source URL and verified date; dev seed is fictional; pilot data is entered by staff from AMC's published pages before launch.
- ASSUMPTION: Escalation is citizen-only (reporter or follower); representatives/moderators act on issues instead.
- ASSUMPTION: Jobs run in-process with `node-cron` (*candidate*) behind `JOBS_ENABLED` and a `pg_try_advisory_lock` per job, plus `npm run jobs:run -- <name>` for manual runs — if TASK-04 already added a runner, reuse it.
- ASSUMPTION: Quiet-hour deferral for issue updates uses TASK-04's push service `notBefore` option; if missing, add it there in coordination with the TASK-04 owner rather than duplicating a queue.
- ASSUMPTION: Citizens may change status ≤ 30 times/day and escalate ≤ 10 times/day (not in Spec §7; abuse guard).
- ASSUMPTION: DS §8 v2.2 ends the verify flow with a toast, so the v2.0 `/issues/:id/verify/done` screen is replaced by a return to the issue plus a toast carrying the same outcome lines; the route redirects to `/issues/:id` for old links.
- ASSUMPTION: The DS §6 "button turns into a progress bar" applies to Send on verify step 2 (the button that does the network work); "Yes, it's fixed" on step 1 only navigates.
- ASSUMPTION: The new timeline step expands with `medium` (not `springIn`) because it is a clipped size animation and an overshoot would make the rows below bounce.
- ASSUMPTION: The status announcement fires only for changes seen while the chip is mounted (not on first build or when scrolling it into view), and the word comes from the DS §2 status table, so TalkBack users get the same information as the colour/icon change.
- ASSUMPTION (build): Jobs use the shared runner `src/jobs` (TASK-08 built it to this task's contract: in-process registry, `pg_try_advisory_xact_lock` per job, `JOBS_ENABLED`, `npm run jobs:run -- <name>`; no `node-cron`). TASK-06 registers `sla-overdue` (cron `5 * * * *`) and `ccrs-reopen-reminder` (every 15 min) from `modules/lifecycle/jobs.ts` in `appJobs()`.
- ASSUMPTION (build): `transition()` has a `transitionInTx(tx, …)` form for callers that already hold a transaction (verification, escalation, TASK-05 CCRS link); they run its `afterCommit()` (notification fan-out) after commit. TASK-10/11 call `transition()` / `transitionInTx()`.
- ASSUMPTION (build): `POST /issues/{id}/status` also accepts `to: rejected` (moderator/admin, note required) so the staff reject transition exists now; TASK-10's `/staff/issues/{id}/reject` should call `transition()` the same way.
- ASSUMPTION (build): The person who made the latest `marked_fixed` change cannot verify it with their own "Fixed" (the answer is recorded, status unchanged) — otherwise a reporter could mark fixed and verify alone.
- ASSUMPTION (build): v2 verification photos are owned by the uploader (`uploaded_by_user_id`); the v1 CHECK `ck_photos_verification_complaint` is widened (migration `20261014060100`) instead of storing an issue id on photos. `POST /photos` checks the named issue exists but does not store it.
- ASSUMPTION (build): After and verification photos get the same on-device face/plate blur as report photos (TASK-03 detector + renderer, automatic; no manual blur screen in these flows).
- ASSUMPTION (build): The CCRS reopen reminder is not held for quiet hours (the AMC reopen window is time-critical); other issue updates are held to 07:00 IST through the push service's `sendAfter`.
- ASSUMPTION (build): The "one push per issue per recipient per 15 min" collapse (§12) is not implemented; actor exclusion is. Revisit if busy issues get noisy.
- ASSUMPTION (build): New read endpoint `GET /issues/{id}/lifecycle` (derived fields, names, location, before/after photo URLs, `viewer.can` actions) feeds the app widgets until TASK-07's detail endpoint exists; TASK-07 may embed the same `viewer` block.
- ASSUMPTION (build): Until TASK-07 ships the detail screen, TASK-06 mounts an interim `/issues/:id` (`IssueLifecycleScreen`: chip, overdue tag, CCRS banner, verify/escalate/AMC-closed buttons, `IssueStatusActions`, animated timeline). TASK-07 should replace the route body and embed `IssueLifecyclePanel`.
- ASSUMPTION (build): Choosing a level on the escalate screen calls `POST /escalations` (which logs the escalation); the suggested level is computed in the app from the timeline with the server's rule, so merely opening the screen logs nothing. "Message corporator" copies the prepared text and opens TASK-09's relay form with `issueId` (that form has no text prefill).
- ASSUMPTION (build): Offline on verify step 2 keeps the answer, photo and idempotency key in the open screen and resends when connectivity returns; it is not persisted across app restarts.
- ASSUMPTION (build): The app has no `merged` status word, so `merged` displays as the closed (rejected) chip.
- ASSUMPTION (build): I-06-01 files the report through the API (TASK-05 endpoints) and runs the verify flow in the app UI with a fake camera/GPS 30 m away; staff steps use the seeded moderator (+919000000025) signed in through the Auth Emulator.

## 6. Implementation Steps

1. **Migration `<ts>_v2_lifecycle`** per §5.2; `escalation_contacts` dev seed (one per level per zone, fictional).
2. **Geo distance lib.** Move v1 `haversineM` from `modules/verify/verify.service.ts` to `src/lib/geo/distance.ts`; add `distanceToIssueM(issueId, lat, lng)` using `ST_Distance`.
3. **Transition table + `transition()`** in `src/modules/lifecycle/` with row lock, idempotency, stale check, role/ward resolution (`representativeWardIds(userId)`), timestamps, SLA reset, event insert; unit tests for every row of the table.
4. **Refactor TASK-05 CCRS link** to call `transition(→ sent)`.
5. **`POST /issues/{id}/status`** handler + Zod schema; after-photo attach; extend `POST /photos` purposes `after` / `verification` with `issueId` ownership.
6. **Verification service + endpoint** per rules 1–7; TASK-05 quota `verifications`.
7. **Derived fields** `derive.ts` used by every issue serializer (TASK-05 nearby/create, TASK-07 list/detail).
8. **Events endpoint** with cursor paging and actor labels (no ids, names or phones of citizens).
9. **Notification fan-out** `notify.ts` with templates in gu/en and actor exclusion; hooked after commit of `transition()` and the overdue/CCRS jobs.
10. **Job runner** `src/jobs/{runner,sla-overdue,ccrs-reopen-reminder}.ts` and `jobs:run` script.
11. **Escalation service + endpoint**; templates in `src/modules/escalation/templates.ts`; event + `→ sent`.
12. **CCRS closed endpoint** + reminder job.
13. **Retire v1 verify API** (`/verify/*` → 410) and v1 verify-token code paths from routing.
14. **API tests** T-06-01…T-06-16.
15. **App: retire v1 verify** routes/screens (`/verify/*`, deep-link token handling) — redirect to Home.
16. **App screens** verify (2 steps + done, reuse `CapturePanel`, upload, blur), mark-fixed, escalate, `CcrsClosedSheet`, `IssueStatusActions`, `issueEventsProvider`; deep links from push payload routes.
17. **Motion (REQ-F-063).** Build `AnimatedStatusChip` (wraps the TASK-03 `StatusChip`; keyed on status; cross-fade `short`; announces via `SemanticsService.announce` with `status.announce`), `AnimatedStatusTimeline` (wraps `StatusTimeline`; diffs event ids so only new steps animate; dot `springIn` + clipped expansion `medium`), the verify Send in-button progress, and the result toast with `MotionCheck` (TASK-03 toast). All widgets read TASK-03's reduced-motion provider and collapse to instant. Replace `/verify/done` with the toast flow and redirect.
18. **Widget + integration tests** W-06-01…W-06-09, I-06-01; motion tests pump through `SaartheeMotion` durations and use the fake haptics helper.
19. **Manual checks** M-06-01…M-06-08 (screen recordings to `docs/demo/v2-evidence/motion/`); coverage matrix.

## 7. Acceptance Criteria

### 7.1 Behavioral

**AC-1** — Transitions enforced by role
- **Given** issues in each status and users with each role (incl. a representative for ward 1 and a citizen who is not the reporter)
- **When** every (from, to, actor) combination is posted to `/status`
- **Then** only rows in the transition table succeed; others return 409 `INVALID_TRANSITION`, 403 `FORBIDDEN_ROLE` or 403 `OUT_OF_WARD` (representative on ward 2); each success writes exactly one `issue_events` row with actor role, from, to and note

**AC-2** — Concurrency and idempotency
- **Given** an issue `in_progress`
- **When** two moderators post `marked_fixed` with `expectedStatus=in_progress` concurrently, and one repeats its `clientActionId`
- **Then** one succeeds, the other gets 409 `STALE_STATUS` with the current status; the repeat returns the original event; one event row exists

**AC-3** — Mark fixed with after photo
- **Given** the reporter of an open issue
- **When** they mark it fixed with one after photo and a note
- **Then** status `marked_fixed`, `marked_fixed_at` set, photo attached as `kind=after`, followers (not the reporter) receive "Is it fixed? Help check" by push and inbox

**AC-4** — Verification distance and photo rules
- **Given** a `marked_fixed` issue
- **When** a citizen answers 150 m away, with 80 m accuracy, with another user's photo, and again on the same day after a valid answer
- **Then** 422 `TOO_FAR_FROM_ISSUE` (with distance), 422 `LOCATION_TOO_INACCURATE`, 422 `PHOTO_UNUSABLE`, 409 `ALREADY_ANSWERED_TODAY`; nothing is stored for the rejected attempts

**AC-5** — Verification outcomes
- **Given** three `marked_fixed` issues
- **When** (a) a neighbour 40 m away answers Fixed; (b) the reporter answers Not fixed; (c) two different neighbours answer Not fixed and one Fixed
- **Then** (a) → `verified`; (b) → `reopened`, `reopened_count=1`, new `sla_due_at`; (c) → `reopened`; each answer has an `issue_verifications` row with `distance_m`, and followers are notified of the outcome

**AC-6** — Reopen window and "Fixed (not verified)"
- **Given** an issue marked fixed 8 days ago with no answers
- **When** its detail/events are read and a citizen tries to verify
- **Then** `displayStatus=fixed_unverified`, `verifyWindowClosesAt` is in the past, and the verification returns 409 `VERIFY_NOT_OPEN`; the app shows "Fixed (not verified)" and "This issue can no longer be checked."

**AC-7** — SLA overdue
- **Given** an open issue whose `sla_due_at` passed an hour ago and a closed one also past due
- **When** `npm run jobs:run -- sla-overdue` runs twice
- **Then** only the open issue gets `isOverdue=true`, one `system` event and one notification to reporter + followers; the second run sends nothing

**AC-8** — Escalation message
- **Given** an overdue open issue in a ward with two corporators and seeded contacts
- **When** the reporter requests each of the four levels in Gujarati and English
- **Then** each response has subject, message with category, ward, days open, target, me-too count, `evidenceUrl` `<base>/i/<id>`, the independence note, and the right targets (2 relay targets; zone office phone/email; DMC; commissioner); `recommendedLevel=corporators` first; an `escalated` event is logged and `reported → sent`; a visitor gets 401 and a non-follower 403

**AC-9** — CCRS 24 h reminder
- **Given** the reporter linked a CCRS number
- **When** they tap "Yes, AMC closed it" and the reminder job runs 20 h later
- **Then** the banner shows the reopen deadline (closed time + 24 h) and "Open AMC site"; one push "Reopen on AMC soon" is sent and not repeated; nothing happens if the issue was verified in between

**AC-10** — Timeline privacy
- **Given** an issue with events by the reporter, a citizen verifier, a representative and a moderator
- **When** `GET /issues/{id}/events` is called without auth
- **Then** citizens appear only as "A resident of <ward>", the representative as role + name, the moderator as "Saarthee moderator"; no user ids, phones or citizen names appear anywhere in the body

**AC-11** — Notifications respect actor and quiet hours
- **Given** an issue with 3 followers including the reporter
- **When** a moderator marks it in progress at 23:00 IST
- **Then** 3 `notifications` rows (kind `issue_update`) exist in each recipient's language, push is deferred to 07:00, the moderator gets none, and the push payload routes to `/issues/<id>`

**AC-12** — Verify flow in the app
- **Given** a follower receives "Is it fixed? Help check"
- **When** they tap it, choose "Yes, it's fixed", take a photo 30 m away and tap Send
- **Then** the app shows "You're about 30 m from the problem", sends once (retry-safe), returns to the issue and shows the toast "Thanks for checking. It's now Verified."

**AC-13** — Status change is animated and announced
- **Given** an issue detail open on an `in_progress` issue with animations and TalkBack on
- **When** a moderator marks it fixed and the screen refreshes (foreground push or pull to refresh)
- **Then** the status chip cross-fades colour, icon and word to "Fixed" over `short`; the new "Fixed" timeline step grows from its dot (dot `springIn`, clipped expansion `medium`) without other steps jumping; TalkBack announces "Status changed to Fixed" once (Gujarati "સ્થિતિ બદલાઈ: ઉકેલાયેલ" when the app is Gujarati); opening a detail that is already Fixed animates and announces nothing

**AC-14** — "Yes, it's fixed" ends in a drawn-check toast and Verified chip
- **Given** a follower on verify step 2 within 100 m of a `marked_fixed` issue
- **When** they tap Send and the API answers with status `verified`
- **Then** Send turns into an in-button progress bar and is disabled while sending; on success the flow returns to the issue, a toast slides up with `springIn` and its check draws (`drawCheck`), the chip cross-fades Fixed → Verified and a "Verified" step expands in; one light haptic fired on the press; on failure the button returns to "Send" with the error and no toast

**AC-15** — Reduced motion and smoothness for lifecycle motion
- **Given** the system "Remove animations" setting on, and separately the in-app Animations switch off
- **When** AC-13 and AC-14 are repeated
- **Then** chip, timeline step and toast appear in their final state instantly (or ≤ 100 ms cross-fade) with identical text, the TalkBack announcement still happens once; with animations on, a profile build on the reference low-end device has no frame over 16 ms during these motions; no `Duration(` literal exists in `lib/features/issue_actions/**`

### AC → Requirement

| AC | Requirements |
|---|---|
| AC-1 | REQ-F-020 |
| AC-2 | REQ-F-020 |
| AC-3 | REQ-F-021, REQ-F-027 |
| AC-4 | REQ-F-022 |
| AC-5 | REQ-F-022, REQ-F-027 |
| AC-6 | REQ-F-023 |
| AC-7 | REQ-F-024, REQ-F-027 |
| AC-8 | REQ-F-025 |
| AC-9 | REQ-F-026 |
| AC-10 | REQ-F-020 |
| AC-11 | REQ-F-027 |
| AC-12 | REQ-F-022 |
| AC-13 | REQ-F-063 |
| AC-14 | REQ-F-063, REQ-F-022 |
| AC-15 | REQ-F-063 |

### 7.2 Non-Functional Checklist

- [ ] No status write anywhere except through `transition()` (grep: no `status:` updates on `issue` outside `modules/lifecycle`)
- [ ] Every transition, verification and escalation is one transaction; notifications sent only after commit
- [ ] Jobs are idempotent and single-instance (advisory lock verified with two processes)
- [ ] Event/notification text never includes citizen names, phones or ids
- [ ] All copy in ARB (gu + en); server templates in both languages; status shown with icon + word (DS §2)
- [ ] Verify/mark-fixed/escalate screens have loading, error, offline, in-flight and unauthorised states; 48 dp targets; TalkBack "Step n of 2"
- [ ] Escalation screens always show the independence line; no AMC logo
- [ ] Notes and messages are not logged
- [ ] Lifecycle motion uses only `SaartheeMotion` tokens and TASK-03 widgets; no `Duration(` literal in `lib/features/issue_actions/**`; reduced motion → instant with identical text; only transform, opacity and colour animate except the clipped timeline expansion
- [ ] Every status change seen on screen is announced once by TalkBack in the app language; status always shown as icon + word, never colour alone
- [ ] Neem styling: Send/Mark as fixed are `primary` (no `sunrise` in these flows); toast `primaryDark` radius 18; sheets radius 24 entering with `springIn`; Material Symbols Rounded icons

## 8. Validation & Testing

| Level | ID | What to test | Proves |
|---|---|---|---|
| Static | S-06-01 | API typecheck + lint; `flutter analyze`, `dart format` check | all |
| API (Vitest+Supertest) | T-06-01 | Table-driven: every (from, to, role) → expected status code; event rows | AC-1 |
| API | T-06-02 | Representative ward scope: own ward 200, other ward 403 `OUT_OF_WARD`, unverified representative 403 | AC-1 |
| API | T-06-03 | Concurrent `marked_fixed` → one 200 + one `STALE_STATUS`; `clientActionId` repeat | AC-2 |
| API | T-06-04 | Mark fixed with after photo; photo of wrong purpose → 422 | AC-3 |
| API | T-06-05 | Verification rejections (distance, accuracy, photo, same day) store nothing | AC-4 |
| API | T-06-06 | Outcomes a/b/c; reopen resets SLA; `reopened` beats `verified` | AC-5 |
| API | T-06-07 | Window: fake clock +8 days → `fixed_unverified`, 409 `VERIFY_NOT_OPEN` | AC-6 |
| API | T-06-08 | `sla-overdue` job twice; closed issue ignored | AC-7 |
| API | T-06-09 | Escalation per level/language; targets; event; `→ sent`; 401/403 | AC-8 |
| API | T-06-10 | CCRS closed + reminder job (fake clock), verified issue skipped, no repeat | AC-9 |
| API | T-06-11 | Events endpoint privacy: response contains none of the seeded phones/names/ids | AC-10 |
| API | T-06-12 | Notify fan-out: recipients, actor excluded, language, `notBefore` in quiet hours (push service mocked) | AC-11 |
| API | T-06-13 | Verification quota 20/day → 429 | AC-4 |
| API | T-06-14 | `/verify/*` → 410 | AC-1 |
| API | T-06-15 | Unit: `haversineM` vs PostGIS within 0.5 m on 10 point pairs | AC-4 |
| API | T-06-16 | Advisory lock: second concurrent job run exits without work | AC-7 |
| Widget | W-06-01 | Verify step 2 distance states (near, too far, inaccurate) and disabled Send | AC-4, AC-12 |
| Widget | W-06-02 | Escalate screen: suggested level, empty corporator list → Copy/Share only, independence line | AC-8 |
| Widget | W-06-03 | Timeline mapping from events (actor labels, after photo on Fixed) | AC-10 |
| Widget | W-06-04 | `CcrsClosedSheet` + banner deadline formatting in gu/en | AC-9 |
| Widget | W-06-05 | `IssueStatusActions` renders by role and handles `STALE_STATUS` | AC-1, AC-2 |
| Widget | W-06-06 | `AnimatedStatusChip`: first build → no animation and no announcement; rebuild `in_progress` → `marked_fixed`: at `short`/2 both chips present with opacities between 0 and 1, after `short` only the Fixed tint, `check_circle` icon and word "Fixed"; announcement captured by mocking `SystemChannels.accessibility` equals "Status changed to Fixed" exactly once (Gujarati string with gu locale); reduced variant (`MediaQuery(disableAnimations: true)` and in-app switch off): final chip on the next frame, announcement still once | AC-13, AC-15 |
| Widget | W-06-07 | `AnimatedStatusTimeline`: adding one event → only the new step animates (dot scale < 1 at frame 0, 1 after `springIn`; `ClipRect` height factor 0 → 1 over `medium`); existing step keys unchanged; initial list of 5 events renders without animation; reduced variant instant | AC-13, AC-15 |
| Widget | W-06-08 | Verify Send: fake API completer → label replaced by in-button `LinearProgressIndicator`, button disabled; fake haptics records one light press; complete with `verified` → routes pop, toast present after `springIn`, its `MotionCheck` progress 1 after `drawCheck`, toast gone after 4 s; chip shows Verified; failure path → button restored, no toast; reduced variant: toast and chip final on the first frame | AC-14, AC-15 |
| Widget | W-06-09 | `/issues/:id/verify/done` redirects to `/issues/:id`; outcome toast copy for verified / reopened / recorded in gu and en | AC-12, AC-14 |
| Static | S-06-02 | TASK-03's `no_duration_literals_test` passes for `lib/features/issue_actions/**` | AC-15 |
| Integration | I-06-01 | Emulator: report (TASK-05 flow) → moderator marks fixed via API → second account verifies with mock location 30 m away → Verified | AC-12, AC-5 |
| Manual | M-06-01 | Push on emulator: tap "Is it fixed?" notification opens verify | AC-11, AC-12 |
| Manual | M-06-02 | Mock location 240 m away → "too far" copy | AC-4 |
| Manual | M-06-03 | Escalate: relay button opens TASK-09 message screen (or Copy/Share when absent), email/dial intents | AC-8 |
| Manual | M-06-04 | CCRS closed banner and reminder (job forced with fake time) | AC-9 |
| Manual | M-06-05 | TalkBack and 2.0× font on verify and escalate | AC-12 |
| Manual | M-06-06 | Emulator screen recordings with animations on: status change on an open detail (moderator call via API while the screen is open), and verify Send → toast → Fixed → Verified: `adb shell screenrecord --bit-rate 8000000 /sdcard/t06-<moment>.mp4`, `adb pull` to `docs/demo/v2-evidence/motion/task-06-status-change.mp4` and `task-06-verify-toast.mp4`; reviewed frame by frame against the §5.4 motion table | AC-13, AC-14 |
| Manual | M-06-07 | TalkBack on: hear "Status changed to Fixed" / "…Verified" once per change in English and Gujarati; record `task-06-talkback.mp4` with audio notes in §13 | AC-13 |
| Manual | M-06-08 | Reduced motion (system "Remove animations" and in-app Animations off): recordings `task-06-reduced-system.mp4`, `task-06-reduced-inapp.mp4`; profile build frame check (`adb shell dumpsys gfxinfo <package> framestats` or DevTools) shows no frame > 16 ms during the animated runs | AC-15 |

## 9. Deliverables

- Migration `<ts>_v2_lifecycle`, `escalation_contacts` dev seed.
- API modules `lifecycle` (transitions, verification, notify, derive), `escalation`, events endpoint, CCRS closed; `src/jobs` runner with two jobs; `src/lib/geo/distance.ts`; v1 verify API retired.
- App: verify flow (ending in a drawn-check toast), mark-fixed, escalate, CCRS closed sheet/banner, `IssueStatusActions`, `issueEventsProvider`, `AnimatedStatusChip` and `AnimatedStatusTimeline` with TalkBack announcements; v1 verify UI removed.
- Tests T-06-01…16, W-06-01…09, S-06-02, I-06-01; motion recordings in `docs/demo/v2-evidence/motion/`; coverage evidence for 9 requirements.

## 10. Files Expected to Change

Prediction only — exact paths may differ.

| Path | Change |
|---|---|
| `apps/api/prisma/migrations/<ts>_v2_lifecycle/`, `prisma/seed/escalation-contacts.ts` | New |
| `apps/api/src/modules/lifecycle/`, `src/modules/escalation/` | New |
| `apps/api/src/modules/issues/` (events route, derive, CCRS refactor), `src/modules/photos/` | Modified |
| `apps/api/src/modules/verify/` (retired → 410) | Modified |
| `apps/api/src/jobs/`, `apps/api/package.json` (`jobs:run`), `src/server.ts` (start scheduler) | New / Modified |
| `apps/api/src/lib/geo/distance.ts`, `src/lib/errors/index.ts` | New / Modified |
| `apps/api/test/lifecycle/*.test.ts`, `test/escalation.test.ts`, `test/jobs.test.ts` | New |
| `apps/mobile/lib/features/issue_actions/` (verify, mark_fixed, escalate, ccrs_closed, `presentation/motion/`) | New |
| `docs/demo/v2-evidence/motion/task-06-*.mp4` | New |
| `apps/mobile/lib/features/verify/` | Removed |
| `apps/mobile/lib/router/citizen_routes.dart`, `router/deep_links.dart`, `lib/core/l10n/*.arb` | Modified |
| `apps/mobile/test/issue_actions/*` (incl. `motion/*_test.dart`), `integration_test/report_verify_test.dart` | New |

## 11. Related Documentation

- `docs/v2/saarthee-v2-spec.md` §3 (roles), §5 (lifecycle rules), §6 (tables), §7 (endpoints, rate limits), §9 (notifications), §11 (privacy)
- `docs/v2/design-system.md` DS §2 (status colours/words, Rounded status icons), §4 (radii), §5 (status chip, status timeline, toast, buttons), §6 Motion (tokens, catalogue rows for TASK-06, reduced motion, accessibility), §7 (accessibility), §8 (verify flow)
- `docs/tasks/TASK-07-verify-flow.md` (v1) — verification photo/distance logic reused
- `docs/tasks-v2/TASK-05-issue-reporting.md` (quota helper, CCRS link), `TASK-04-*.md` (push service), `TASK-09-*.md` (relay), `TASK-07-discovery.md` (detail screen, `/i/{id}` page)

## 12. Risks & Considerations

| Risk | Impact | Mitigation |
|---|---|---|
| GPS spoofing to verify remotely | False "Verified" | Photo required, accuracy cap, distance logged, moderators can reopen (TASK-10); repeated far attempts visible in data |
| Notification storms on busy issues | Users mute the app | Actor excluded; one push per issue per recipient per 15 min (collapse key = issue id) |
| Representative scope bugs | Rep changes another ward's issue | Table-driven tests T-06-01/02; ward check inside `transition()`, not handlers |
| Escalation contacts outdated | Messages to wrong office | `source_url` + `last_verified_at` shown to staff; pilot checklist in TASK-14 |
| Job runs twice on two instances | Duplicate pushes | Advisory lock + `*_notified_at` columns |
| Clock/timezone errors (IST day uniqueness, quiet hours) | Wrong rejections or night pushes | All day math in `Asia/Kolkata` helper with tests at 23:59/00:01 |
| Repeated announcements or animations on every rebuild/refresh | TalkBack noise, distracting UI | Animate and announce only when the status value changes on a mounted chip; timeline diffs by event id; W-06-06/07 cover first build |

## 13. Progress Status

**Current status:** In Review (emulator, push, TalkBack and recording checks pending — integrator)

**Progress:** 90% (all code and automated tests done; emulator-only checks remain)

| Date | Progress | Commit |
|---|---|---|
| 2026-10-04 | Migrations `20261014060000_v2_lifecycle` (+ `…0100` photo CHECK), `transition()` state machine with row lock, idempotency, stale check, ward scope, SLA reset; notify fan-out; derived fields; CCRS link on `transitionInTx` | a2698d2 |
| 2026-10-04 | Verification, events timeline, escalation, AMC closed it, `sla-overdue` / `ccrs-reopen-reminder` jobs in `appJobs()`, after/verification photo uploads, escalation contacts dev seed (15 rows) | cc1b376 |
| 2026-10-04 | API tests T-06-01…16 + single-writer static check + `GET /issues/{id}/lifecycle` (363 API tests green, tsc/eslint clean, drift gate OK) | 57bc826, 78ff44a, 57c320f, d8b08e3 |
| 2026-10-04 | App: data/providers, ARB `issueActions*` block (en+gu, gu pending review), `AnimatedStatusChip`, `AnimatedStatusTimeline`, `SendProgressButton`, verify 2 steps + toast, mark fixed, escalate, AMC-closed sheet/banner, `IssueStatusActions`, `/issues/:id` interim screen, routes + v1 `/verify/*` redirect, push allow-list `/issues/:id/verify` | dcb6f57…c79d9c1 |
| 2026-10-04 | Widget tests W-06-01…09 (+ mark fixed), 341 Flutter tests green, `dart analyze` 0, format clean; emulator integration test `integration_test/report_verify_test.dart` written (not run here) | 9cdeedd…HEAD |

## 14. Completion Checklist

- [x] All implementation steps complete (step 19 manual checks M-06-01…08 are the integrator's)
- [ ] All behavioral acceptance criteria verified in the running application
- [ ] Non-functional checklist fully ticked
- [ ] Static checks pass and every AC verified by the tests and manual checks in §8
- [x] Automated tests added and passing
- [x] Frontend and backend integrated end to end (no mocked data left in place)
- [ ] Error, loading, empty, and unauthorized states verified
- [x] Code reviewed against the patterns established in earlier tasks
- [x] Assumptions documented and, where possible, confirmed
- [ ] Lifecycle motion (REQ-F-063) verified: W-06-06…W-06-09 green, TalkBack announcement heard, normal and reduced-motion recordings in `docs/demo/v2-evidence/motion/`, no frame > 16 ms in the profile check
- [ ] Coverage matrix rows for this task's requirements set to Pass with evidence (`check_coverage.py --task TASK-06` shows 0 unverified)
- [ ] Task file progress log and status updated
- [ ] `00-task-summary.md` updated
- [x] Committed as `V2-TASK-06: …`
- [ ] Validator passes
