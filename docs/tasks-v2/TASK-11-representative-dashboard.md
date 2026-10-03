# TASK-11: Representative Claim and Ward Dashboard

| Field | Value |
|---|---|
| Task ID | TASK-11 |
| Status | Not Started |
| Priority | P1 |
| Size | M |
| Depends On | TASK-06, TASK-09, TASK-10 |
| Blocks | TASK-14 |
| Requirement IDs | REQ-F-053, REQ-F-054, REQ-F-055, REQ-F-056, REQ-F-066 |
| Primary Spec Refs | Spec §3, §5, §6 (`representatives`, `rep_claims`, `rep_messages`), §7 (Representatives, Staff), §8 (`/staff/*`), §11 (Neutrality); DS §2–§4 (Neem tokens, Baloo Bhai 2 / Mukta Vaani, radii, Rounded icons), DS §5 (Representative row, list rows, chips, Stat tiles), DS §6 (Motion: Scorecard and dashboards; Staff console), DS §7, DS §9 (Representative: Ward dashboard, Ward issues, Messages) |
| Last Updated | 2026-10-03 |

## 1. Objective

Let an elected representative take ownership of their Saarthee profile and act on the issues in their own wards, without giving them any power over verification or over other wards. At the end of this task:
- a representative signs in with phone OTP, claims their profile with evidence (for example a photo of the certificate of election), and an admin approves or rejects the claim in the staff console;
- the public profile shows a "Verified representative" badge with method and date, which expires automatically at `term_end` and must be claimed again for a new term;
- a verified representative sees a ward dashboard (open issues by category and age bucket 0–7 / 8–30 / > 30 days, overdue list, hotspots map, 12-week resolution trend, CSV export) for their wards only; its numbers count up and its bars grow the first time they are seen, never on every rebuild, using the scorecard widgets shared from TASK-09 (DS §6);
- they can acknowledge, comment on and mark fixed issues in their wards, and never verify, reject, merge, hide or close;
- (P2) they read relayed citizen messages in an inbox and replies sent by email are tracked;
- neutrality and election mode apply: identical features for every representative, no party marks, no cross-ward ranking, and authored content is frozen while election mode is on.

This task completes milestone **V2-M5 Operators** together with TASK-10.

## 2. Scope

### In Scope
- **Claim flow (citizen side):** "Is this you? Claim this profile" link on `/representatives/:id`, sign-in gate (TASK-04), evidence upload (1–3 photos via `POST /photos` with new purpose `rep_evidence`), check and submit, "Claim sent" confirmation, claim status on the Me screen.
- **Claim review (staff side):** `/staff/claims` list and `/staff/claims/:id` detail in the TASK-10 console shell; evidence photos viewable by admins only; phone-match signal; approve (with method) or reject (with reason); claimant notified (push + inbox via TASK-04 push service).
- **Verification lifecycle:** verified badge on the public profile (method + date + valid until); `reps:expire` daily job plus request-time term check; re-claim for each term; session token version bumped on expiry or revocation; admin "Revoke verification" action.
- **Ward dashboard:** `GET /staff/ward-dashboard?ward=` and `GET /staff/ward-dashboard/export?ward=` (CSV), Flutter screen `/staff/ward` with ward switcher, category × age table, overdue list, hotspots map, trend chart, empty/loading/error/offline states.
- **Representative actions:** ward-scope guard on TASK-06's `POST /issues/{id}/status` for the `representative` role (acknowledge, mark fixed only), `POST /staff/issues/{id}/comments`, `/staff/ward/issues` list with action sheet.
- **Messages inbox (P2):** `/staff/messages` list and detail, in-app reply, inbound email webhook that records replies sent by email, citizen sees the reply in `/me/messages`.
- **Dashboard motion (REQ-F-066, DS §6 "Scorecard and dashboards"):** the four stat tiles count up (`countUp`) and the trend bars and category-total bars grow from 0 (`long`) on the first view of each ward in the session, reusing TASK-09's `ScorecardStatTile`, `ScorecardBar` and `SeenOnce` from `lib/core/widgets/scorecard/`; everything else in the console keeps TASK-10's `short`-fades-only rule; reduced-motion variants.
- **Neutrality and election mode:** enforcement of TASK-09's election-mode flag on every authored write in this task; no party colour or logo; no ranking against other wards.
- **Tests:** Vitest + Supertest for claims, decisions, scope, transitions, dashboard numbers, CSV, election mode, inbound replies; Flutter widget tests for the claim screens, dashboard and badge.

### Out of Scope
- The representative roster, profile screen, message relay send path, election-mode setting UI and `rep_claims` / `rep_messages` base tables — TASK-09 (REQ-F-042…047, REQ-D-008).
- The state machine itself, `issue_events`, after-photos and notifications on status change — TASK-06 (this task only adds the representative scope check and uses its transitions).
- The staff console shell, role middleware, audit-log extension and moderation — TASK-10.
- Delegate / personal-assistant accounts acting for a representative — P2, not built (see §5.6).
- Representative-authored public ward updates (Spec §3 "(P2) ward updates") — not built.
- Public ward scorecard — TASK-09 (REQ-F-046), including building the shared scorecard widgets this task reuses.
- Motion tokens and helpers (`SaartheeMotion`, `CountUp`, reduced-motion switch) — TASK-03; staff fade policy (`StaffMotionScope`) — TASK-10; frame-time audit — TASK-14 (REQ-N-013).

## 3. Prerequisites

- TASK-06 complete: `POST /issues/{id}/status` with role-checked transitions, `issue_events` append, after-photo support, follower notifications.
- TASK-09 complete: `representatives`, `representative_areas`, `assembly_constituencies`, `ward_constituency`, `rep_claims`, `rep_messages` tables; `GET /representatives/{id}`; relay email sender (`src/lib/mail`); election-mode helper `isElectionMode(wardId)`; seeded fictional representatives for the 5 pilot wards with `term_start`/`term_end`.
- TASK-09 shared scorecard widgets `ScorecardStatTile`, `ScorecardBar`, `SeenOnce` in `apps/mobile/lib/core/widgets/scorecard/` (first-view `CountUp` and bar growth).
- TASK-03: Neem tokens, type scale, radii 14/18/24/pill, Material Symbols Rounded; motion foundation — `SaartheeMotion` tokens (`lib/core/theme/motion.dart`), `animations` + `flutter_animate`, `CountUp`, `StaggeredColumn`, `MotionCheck`, reduced-motion resolution.
- TASK-10 complete: staff console shell (Flutter web + in-app `/staff`), `StaffMotionScope` (`short` fades only), `requireRole()` middleware, role-aware navigation, staff audit log helper with actor/role/target, staff photo viewer endpoint pattern, CSV helper usage for exports.
- TASK-04: Firebase OTP sign-in, session JWT with `token_version`, push + inbox service (`notify(userId, …)`).
- Env vars (added to `apps/api/.env.example`): `REP_CLAIM_MAX_PER_DAY=3`, `REP_EXPORT_MAX_PER_HOUR=10`, `MAIL_INBOUND_SECRET`, `MAIL_REPLY_DOMAIN` (e.g. `reply.saarthee.local` in dev), `REP_DASHBOARD_HOTSPOT_CELL_M=150`.

## 4. Dependencies

| Task | Why it is required |
|---|---|
| TASK-06 | Issue state machine, `issue_events`, mark-fixed with after photo, and notifications that representative actions trigger |
| TASK-09 | Representative records, ward/constituency mapping, `rep_claims` / `rep_messages` tables, relay email sender and the election-mode flag |
| TASK-10 | Staff console shell and navigation, `requireRole()`, audit logging of staff actions, export conventions |

## 5. Technical Context

### 5.1 Requirements Covered

| Req ID | Requirement | Source |
|---|---|---|
| REQ-F-053 | Representative claim flow: OTP-verified phone plus evidence upload, reviewed and approved by an admin | Spec §6 |
| REQ-F-054 | Representative ward dashboard: open issues by category and age, overdue list, hotspots map, resolution trend, CSV export | Spec §7 |
| REQ-F-055 | Representatives can acknowledge, comment and mark fixed on issues in their wards only | Spec §3, §5 |
| REQ-F-056 | Representative inbox for relayed messages with reply-by-email tracking | Spec §7 |
| REQ-F-066 | Dashboard motion per DS §6: numbers count up and bars grow on first view only (representative ward dashboard and ward scorecard widgets shared from TASK-09) | DS §6 |

Related requirements owned elsewhere and re-checked here: REQ-S-002 (role and ward scoping, TASK-10), REQ-F-047 (election mode, TASK-09), REQ-S-010 (audit log, TASK-10), REQ-S-012 (no personal numbers, TASK-09).

### 5.2 Data Contracts

New forward migration `apps/api/prisma/migrations/<timestamp>_v2_rep_claims_dashboard/` (never edit applied ones):

```sql
-- rep_claims (base table from TASK-09): add review fields
ALTER TABLE rep_claims
  ADD COLUMN phone_match boolean NOT NULL DEFAULT false,      -- OTP phone equals a declared number on record
  ADD COLUMN claimant_note varchar(500),
  ADD COLUMN reject_reason varchar(300),
  ADD COLUMN verified_method varchar(30),                      -- set on approve
  ADD COLUMN term_end date;                                    -- snapshot of representatives.term_end at decision
ALTER TABLE rep_claims ADD CONSTRAINT rep_claims_status_chk
  CHECK (status IN ('pending','approved','rejected','expired','revoked','withdrawn'));
CREATE UNIQUE INDEX rep_claims_one_pending ON rep_claims(representative_id, user_id) WHERE status = 'pending';

-- representatives (TASK-09): verification is per term
ALTER TABLE representatives ADD CONSTRAINT representatives_verified_method_chk
  CHECK (verified_method IS NULL OR verified_method IN ('certificate_of_election','official_gazette','in_person','official_email'));
CREATE UNIQUE INDEX representatives_user_active ON representatives(user_id) WHERE user_id IS NOT NULL;

-- rep_messages (TASK-09): reply tracking
ALTER TABLE rep_messages
  ADD COLUMN reply_token char(32) UNIQUE,                       -- random, in Reply-To address
  ADD COLUMN replied_at timestamptz,
  ADD COLUMN reply_channel varchar(10) CHECK (reply_channel IN ('email','in_app')),
  ADD COLUMN reply_body varchar(2000),
  ADD COLUMN read_by_rep_at timestamptz;

-- issue_photos.kind / photos.purpose: add 'rep_evidence' (private; never attached to an issue)
```

- `photos.purpose = 'rep_evidence'` rows are readable only through `GET /staff/rep-claims/{id}/evidence/{photoId}` (admin). They are deleted 90 days after the claim is decided (added to TASK-13's retention job list; this task provides the query).
- `phone_match` is computed at claim time: normalise the user's verified `phone_e164` and compare with `representatives.public_phone` (normalised). The phone number itself is never copied into `rep_claims` or shown to reviewers; reviewers see only "Phone matches the number on record: Yes / No".
- Ward scope of a representative (SQL view `rep_scope_wards_v`): `representative_areas.ward_id` ∪ wards joined through `ward_constituency` for MLA/MP rows; only rows with `verified_at IS NOT NULL AND term_end >= current_date AND user_id = :userId`.
- Dashboard aggregates read `issues` (excluding `visibility='hidden'`, `status IN ('rejected','merged')`). Open = `reported, sent, acknowledged, in_progress, reopened`. Age = `now() - created_at` in whole days: buckets `0–7`, `8–30`, `> 30`. Overdue = open and `sla_due_at < now()`. Trend = per ISO week for the last 12 weeks: `reported` (created), `marked_fixed` (first `issue_events` to `marked_fixed`), `verified` (event to `verified`). Hotspots = open issues snapped to a `REP_DASHBOARD_HOTSPOT_CELL_M` grid (`ST_SnapToGrid` on a metric projection), cells with ≥ 2 issues, top 30.
- Seed (extends TASK-01 dev seed, fictional only): one approved claim (Navrangpura corporator linked to seed user `rep.demo`), one pending claim, one rejected claim, one expired verification (term ended yesterday), 6 relayed messages (2 replied by email, 1 in-app).

### 5.3 API Contracts

All under `/api/v1`. Error shape and `AppError` codes per v1 conventions. New codes added to `src/lib/errors`:

| Code | HTTP | Message (en; mirrored in ARB `errorCode_<CODE>`) |
|---|---|---|
| `CLAIM_ALREADY_PENDING` | 409 | "You already have a claim waiting for review." |
| `REPRESENTATIVE_ALREADY_VERIFIED` | 409 | "This profile is already verified. Contact Saarthee if this is wrong." |
| `REPRESENTATIVE_TERM_ENDED` | 422 | "This term has ended. Claims are open only for the current term." |
| `ROLE_CONFLICT` | 409 | "Staff accounts can't also be representative accounts. Use a separate phone number." |
| `WARD_OUT_OF_SCOPE` | 403 | "You can only act on issues in your wards." |
| `ELECTION_MODE_FROZEN` | 409 | "Election mode is on. Comments and updates are paused until it ends." |

| Method | Path | Auth / role | Request | Response | Errors | Rate limit |
|---|---|---|---|---|---|---|
| POST | `/photos` | citizen | multipart `photo`, `purpose=rep_evidence` | 201 `{photoId}` | 413, 415, 429 | existing photo limit |
| POST | `/representatives/{id}/claims` | citizen (OTP session) | `{evidencePhotoIds: uuid[1..3], note?: string≤500}` | 201 `{claimId, status:"pending"}` | 400, 404, 409 `CLAIM_ALREADY_PENDING` / `REPRESENTATIVE_ALREADY_VERIFIED` / `ROLE_CONFLICT`, 422 `REPRESENTATIVE_TERM_ENDED` / `PHOTO_UNUSABLE` | `REP_CLAIM_MAX_PER_DAY` (3)/user/day |
| GET | `/me/rep-claims` | citizen | — | `{items:[{claimId, representative:{id,nameEn,nameGu,role}, status, createdAt, decidedAt, rejectReason}]}` | 401 | public read |
| DELETE | `/me/rep-claims/{claimId}` | claimant | — | 204 (status `withdrawn`) | 404, 409 if not pending | — |
| GET | `/representatives/{id}` | none | — | adds `verification:{status:"verified"|"unverified"|"expired", method, verifiedAt, validUntil}` | 404 | 120/IP/min |
| GET | `/staff/rep-claims?status=pending&cursor` | admin, moderator (read) | — | `{items:[{claimId, representative, claimant:{displayName, ward}, phoneMatch, evidenceCount, createdAt, status}], nextCursor}` | 401, 403 | — |
| GET | `/staff/rep-claims/{id}` | admin, moderator (read) | — | detail + `evidence:[{photoId}]`, `claimantNote`, `otpVerified:true` | 404 | — |
| GET | `/staff/rep-claims/{id}/evidence/{photoId}` | admin | — | `image/jpeg` (no-store) | 404, 410 `PHOTO_DELETED` | — |
| POST | `/staff/rep-claims/{id}/decide` | admin | `{decision:"approve"|"reject", method?: verified_method (required on approve), reason?: string 5–300 (required on reject)}` | 200 `{claimId, status}` | 400, 404, 409 (not pending / already verified / `ROLE_CONFLICT`), 422 `REPRESENTATIVE_TERM_ENDED` | — |
| POST | `/staff/representatives/{id}/revoke-verification` | admin | `{reason: string 5–300}` | 200 | 404, 409 if unverified | — |
| GET | `/staff/ward-dashboard?ward={wardId}` | representative (own scope), moderator, admin | — | see below | 400, 403 `WARD_OUT_OF_SCOPE` | 60/user/min |
| GET | `/staff/ward-dashboard/export?ward&from&to` | same | dates ISO, max 366 days | `text/csv; charset=utf-8`, `Content-Disposition: attachment; filename="saarthee-ward-<n>-<yyyymmdd>.csv"` | 400, 403 | `REP_EXPORT_MAX_PER_HOUR` (10)/user/h |
| GET | `/staff/ward/issues?ward&status&overdue&cursor` | same | — | `{items:[issue card fields + allowedActions[]], nextCursor}` | 403 | — |
| POST | `/issues/{id}/status` (TASK-06) | representative | `{to:"acknowledged"|"marked_fixed", note?: ≤500, afterPhotoId?}` | 200 issue | 403 `WARD_OUT_OF_SCOPE`, 409 transition not allowed (TASK-06 code), 409 `ELECTION_MODE_FROZEN` when `note` present | TASK-06 limits |
| POST | `/staff/issues/{id}/comments` | representative (scope), moderator, admin | `{note: string 1–500}` | 201 `{eventId}` (`issue_events.type='comment'`) | 403, 409 `ELECTION_MODE_FROZEN` (representative only) | 30/user/h |
| GET | `/staff/rep-messages?status&cursor` (P2) | representative | — | `{items:[{id, subject, bodyPreview, issueId, citizenLabel, sharedPhone?, createdAt, status, repliedAt, readByRepAt}], nextCursor, unread}` | 403 | — |
| GET | `/staff/rep-messages/{id}` (P2) | representative (own) | — | full message; sets `read_by_rep_at` | 403, 404 | — |
| POST | `/staff/rep-messages/{id}/reply` (P2) | representative (own) | `{body: string 1–2000}` | 200 `{status:"replied", repliedAt}` | 403, 404, 409 already replied | 20/user/day |
| POST | `/webhooks/mail-inbound` (P2) | HMAC `X-Saarthee-Signature` with `MAIL_INBOUND_SECRET` | provider JSON `{to, from, text, receivedAt}` | 202 | 401 bad signature, 200 ignored unknown token | 60/IP/min |
| GET | `/me/messages` (P2) | citizen | — | `{items:[{id, representative, subject, status, sentAt, repliedAt, reply}]}` | 401 | — |

Ward dashboard response:

```json
{
  "ward": {"id": 12, "number": 12, "nameEn": "Navrangpura", "nameGu": "નવરંગપુરા"},
  "generatedAt": "2026-10-03T10:00:00Z",
  "totals": {"open": 41, "overdue": 9, "markedFixed30d": 14, "verified30d": 8},
  "byCategory": [{"slug": "roads", "d0_7": 3, "d8_30": 5, "d31Plus": 2, "total": 10}],
  "overdue": [{"issueId": "…", "title": "Pothole near …", "category": "roads", "status": "acknowledged", "ageDays": 19, "slaDueAt": "…", "meTooCount": 7}],
  "hotspots": [{"lat": 23.0365, "lng": 72.5611, "count": 5}],
  "trend": [{"weekStart": "2026-07-13", "reported": 6, "markedFixed": 3, "verified": 2}]
}
```

`overdue` returns the 50 oldest by `sla_due_at`; the full list is in `/staff/ward/issues?overdue=true`. No reporter identity, phone or name anywhere in these responses (Spec §11).

CSV columns (fixed order, `csvRow` helper, formula-safe): `issue_id, created_at, category, status, age_days, sla_due_at, overdue, me_too_count, follower_count, latitude(4 dp), longitude(4 dp), ward_number, last_status_change_at, ccrs_linked(yes/no)`. Never: reporter id, phone, name, description, photos. Each export writes an audit line `ward_export` with actor, role, ward and row count.

Representative transition rules (scope check runs before TASK-06's state machine):

| From → To | Representative | Notes |
|---|---|---|
| `reported` / `sent` → `acknowledged` | ✅ | |
| `reported` / `sent` / `acknowledged` / `in_progress` / `reopened` → `marked_fixed` | ✅ | after photo optional (TASK-06) |
| any → `in_progress`, `verified`, `rejected`, `merged`, hide | ❌ 403 | verification is citizens' only; moderation is staff only |

Audit actions added to `AUDIT_ACTIONS` (TASK-10 helper): `rep_claim_submitted`, `rep_claim_decided`, `rep_verification_revoked`, `rep_verification_expired`, `rep_issue_status`, `rep_issue_comment`, `ward_export`, `rep_message_replied`. Lines carry actor ID, role, target ID and decision/method only — never note text, message bodies or phone.

### 5.4 UI Surfaces & States

All strings in `app_en.arb` and `app_gu.arb` (keys prefixed `repClaim*`, `wardDash*`, `repMsg*`); tokens and components only from DS §2–§5.

| Route | Content | States |
|---|---|---|
| `/representatives/:id` (TASK-09 screen, extended) | Verified badge row: icon `verified` + "Verified representative" / "ચકાસાયેલ પ્રતિનિધિ", helper "Checked by Saarthee on 3 Oct 2026 · Certificate of election · Valid until 31 Mar 2031"; unverified: text link "Are you {name}? Claim this profile" | expired → "Verification ended with the term" (no badge); election mode banner from TASK-09 |
| `/representatives/:id/claim` (step 1 of 2) | Title "Claim this profile"; body "Upload a clear photo of your certificate of election or another official document that shows your name and ward. Only Saarthee admins see it."; `EvidencePhoto` picker (camera or gallery, 1–3); optional note "(optional)" | not signed in → sign-in gate returns here; upload progress/retry; offline banner, draft kept in memory; term ended → error panel with `REPRESENTATIVE_TERM_ENDED` copy |
| `/representatives/:id/claim/check` (step 2 of 2) | Summary with Change links; consent line "I confirm I am {name} and the documents are genuine. False claims lead to account suspension."; primary "Send claim" | sending (in-button progress); `ErrorSummary` with focus on error; 409 pending → "You already have a claim waiting for review." + "See my claims" |
| `/representatives/:id/claim/done` | "Claim sent. We'll review it, usually within 2 working days. We'll notify you." Primary "Done" | — |
| `/me` → "My representative claims" row | Status chips: Waiting for review / Approved / Not approved (reason) / Ended with term | empty row hidden |
| `/staff/claims` (admin, moderator read) | Table/list: representative, claimant display name, ward, phone match chip (Yes = `success` tint + icon `check`; No = neutral + icon `remove`), evidence count, submitted; filter chips Pending / Approved / Not approved | skeleton rows; empty "No claims waiting."; error + "Try again"; 403 → TASK-10 unauthorised screen |
| `/staff/claims/:id` | Evidence photos (tap to zoom; "Evidence — visible to admins only"), claimant note, representative record (name, role, term, source link), phone-match line; actions "Approve" (dialog: method select, required) and "Reject" (dialog: reason, 5–300) | moderator sees read-only with "Only admins can decide claims."; decision in flight disables both; 409 conflict message |
| `/staff/representatives/:id` (TASK-10/09 screen) | Adds "Revoke verification" (destructive, reason required) | — |
| `/staff/ward` Ward dashboard (representative default page) | Ward switcher (only scope wards); totals row (4 stat tiles: Open, Overdue, Fixed in 30 days, Verified in 30 days); "Open issues by category and age" table (rows = categories with badge, columns 0–7 days / 8–30 days / Over 30 days / Total); "Overdue" list (issue rows with overdue tag, tap → `/issues/:id`); "Hotspots" map (muted basemap, slate circles sized by count, list fallback for TalkBack); "Resolution trend" 12-week line/bar chart with data table toggle; "Download CSV" (secondary) | skeletons; empty ward "No open issues in this ward."; error + "Try again"; offline → last loaded dashboard with "Showing data from {time}"; election mode banner "Election mode is on. Comments are paused." |
| `/staff/ward/issues` | Issue list with filters (status, overdue); row action sheet: "Acknowledge", "Mark fixed" (optional after photo + note), "Add comment"; only actions in `allowedActions` shown | action in flight; 403 out of scope → snackbar "You can only act on issues in your wards."; 409 frozen → disabled "Add comment" with helper text |
| `/staff/messages` (P2) | Inbox with unread dot, citizen label "A resident of {ward}", issue link, status chip Sent / Replied; detail shows body, "Reply" field (2,000 chars) and "Replied by email on {date}" when tracked | empty "No messages yet."; error; offline |
| `/me/messages` (P2) | Citizen's sent messages with status and the reply text | empty "You haven't messaged a representative yet." |

Staff navigation for role `representative` (TASK-10 shell, DS §9): Ward dashboard · Ward issues · Messages. Charts use the dataviz rules of DS §2 neutral palette; no party colours anywhere.

Visuals (Neem v2.2 via TASK-03 tokens): stat tiles per DS §5 (`surfaceAlt`, radius 14, number in numeric style — Baloo Bhai 2 20/24 tabular — label in bodySmall Mukta Vaani); section titles titleLarge (Baloo Bhai 2 19/26); cards and table containers radius 18 with 1 px `border`; trend bars `primary` on a `surfaceAlt` track, with category totals as horizontal `ScorecardBar`s; status chips use the DS §2 tints with Rounded icons; no `sunrise` in the console.

#### Motion (REQ-F-066, DS §6)

All durations and curves come from TASK-03 `SaartheeMotion`; no `Duration(` literal in `lib/features/**`. This is the one place in the staff console where TASK-10's "`short` fades only" rule is lifted, because DS §6 lists it explicitly.

| Moment | Behaviour | Tokens / helper | Reduced motion |
|---|---|---|---|
| Stat tiles (Open, Overdue, Fixed in 30 days, Verified in 30 days) | Count up from 0 to the value (`countUp`, 600 ms, `easeOutCubic`, integers only) the first time the dashboard for a ward is shown in the session | `ScorecardStatTile(animateKey: 'ward-dash-<wardId>-<metric>')` (TASK-09) wrapping `CountUp` | Final value at once |
| Trend bars (12 weeks) and category-total bars | Grow from 0 (`scaleX`/`scaleY` from the baseline, clipped; no layout animation) over `long` when first scrolled into view for that ward | `ScorecardBar(animateKey: …)`, `SeenOnce` | Full bars at once |
| Rebuilds | Pull-to-refresh, polling, returning to the page, resizing the web window, toggling "Show as table" and switching back to a ward already seen show final values without replay | `SeenOnce` (session-scoped) | — |
| Everything else (ward switcher, table, overdue list, hotspots, page changes) | TASK-10 `short` fades only; no staggers or springs | `StaffMotionScope` | Instant |

### 5.5 Permissions & Roles

| Action | Visitor | Citizen | Representative (verified, in term) | Moderator | Admin |
|---|---|---|---|---|---|
| See verified badge | ✅ | ✅ | ✅ | ✅ | ✅ |
| Submit / withdraw own claim | ❌ (sign-in) | ✅ | ❌ (already verified for that record) | ❌ `ROLE_CONFLICT` | ❌ `ROLE_CONFLICT` |
| View claims and evidence | ❌ | ❌ | ❌ | list/detail ✅, evidence ❌ | ✅ |
| Approve / reject / revoke | ❌ | ❌ | ❌ | ❌ | ✅ |
| Ward dashboard + CSV | ❌ | ❌ | own scope wards only | any ward | any ward |
| Acknowledge / mark fixed | ❌ | reporter mark-fixed (TASK-06) | own scope wards only | ✅ (TASK-06) | ✅ |
| Comment (staff comment) | ❌ | ❌ | own scope; blocked in election mode | ✅ | ✅ |
| Verify, reject, merge, hide, recategorise | ❌ | verify per TASK-06 | ❌ never | ✅ (TASK-10) | ✅ |
| Message inbox / reply | ❌ | own sent messages | own messages only | ❌ (bodies private) | ❌ (metadata only) |

A representative whose verification expires or is revoked has `users.role` set back to `citizen` and `token_version` incremented, so open staff sessions end at the next request (`TOKEN_REVOKED`).

### 5.6 Assumptions

- ASSUMPTION: "OTP phone compared to any declared number on record" uses only `representatives.public_phone` (office or consented number, TASK-09). Personal numbers are never imported (REQ-S-012), so a mismatch is common and is shown as a signal, not a blocker; evidence review by an admin is always required. If wrong: add a private, admin-entered comparison number that is hashed and never displayed.
- ASSUMPTION: Evidence is photos only (the v2 photo pipeline handles JPEG); PDFs are not accepted. Photograph a PDF or printout. If wrong: add a PDF purpose with size and type checks.
- ASSUMPTION: Verification is valid for one term; it ends automatically at `term_end` (daily `reps:expire` job at 00:30 IST plus a request-time check), and the new term's record must be claimed again. Mid-term re-verification is not required.
- ASSUMPTION: Staff accounts (moderator/admin) cannot also be representatives (`ROLE_CONFLICT`); `users.role` is a single value (Spec §6). If wrong: move to a role set.
- ASSUMPTION: MLA and MP representatives get the same dashboard and actions over every ward mapped to their constituency through `ward_constituency`; corporators over their single ward.
- ASSUMPTION: Representatives may acknowledge and mark fixed but not set `in_progress` (Spec §3 lists acknowledge and comment; §5 lists mark fixed). If wrong: add `in_progress` to the representative rule table.
- ASSUMPTION: Election mode freezes representative-authored text: staff comments by representatives, notes on status changes and in-app replies are blocked (`ELECTION_MODE_FROZEN`); status changes without a note and replies by email remain allowed and tracked, because they are service actions, not campaigning. Existing representative comments stay visible. Legal review (summary Open Question 6) may tighten this.
- ASSUMPTION: Reply-by-email tracking uses a per-message Reply-To address `reply+<reply_token>@MAIL_REPLY_DOMAIN` handled by the mail provider's inbound webhook (provider chosen in TASK-09/TASK-13); quoted history is stripped by cutting at the first line starting with `>` or "On … wrote:". Reply text is shown only to the citizen who sent the message. In dev, a `scripts/mail-inbound-sim.ts` posts a signed payload.
- ASSUMPTION: Delegate / PA accounts (an assistant acting for a representative) are P2 and not built in v2; representatives must use their own login. If added later: a `rep_delegates` table with admin approval and actions logged as "on behalf of".
- ASSUMPTION: "First view" for dashboard motion is per ward per app session (cleared on reload of the web app or app restart); switching to a ward not yet seen animates once for that ward. DS §6 says "when first seen, not on every rebuild" without defining the session.
- ASSUMPTION: The category × age table cells and the overdue list do not count up (DS §6 names numbers in stat tiles and bars); only the four stat tiles, trend bars and category-total bars animate.
- ASSUMPTION: Evidence photos are deleted 90 days after the decision (privacy minimisation); TASK-13 runs the deletion with its retention jobs.

## 6. Implementation Steps

1. **Migration.** Create `<timestamp>_v2_rep_claims_dashboard` per §5.2; update `schema.prisma`; add `rep_scope_wards_v`; run `prisma generate`, typecheck, lint.
2. **Errors, audit, config.** Add the six error codes, the audit actions, and the env vars (Zod config + `.env.example`).
3. **Scope helper.** `src/modules/representatives/scope.ts`: `getRepScope(userId) → {representativeIds, wardIds}` (cached per request); `requireWardScope(wardId)` middleware returning `WARD_OUT_OF_SCOPE`; request-time term check (`term_end >= today`).
4. **Claim submission.** `src/modules/rep-claims/`: Zod schema, photo checks (purpose `rep_evidence`, owned by caller, unattached, < 24 h), term check, role conflict, pending uniqueness (partial unique index → map violation to `CLAIM_ALREADY_PENDING`), `phone_match` computation, insert, attach photos, audit `rep_claim_submitted`, limiter 3/user/day. `GET /me/rep-claims`, `DELETE /me/rep-claims/{id}`.
5. **Claim review.** Staff list/detail/evidence endpoints with `requireRole('admin','moderator')` (evidence and decide: admin only). Decide in one transaction: claim → approved/rejected; on approve set `representatives.user_id`, `verified_at`, `verified_method`, `rep_claims.term_end`; `users.role='representative'`; reject other pending claims for that record with reason "Another claim was approved"; audit; notify claimant via push + inbox ("Your claim for {name} was approved" / "…was not approved: {reason}").
6. **Revoke and expire.** `POST /staff/representatives/{id}/revoke-verification`; `scripts/reps-expire.ts` (`npm run reps:expire`) expiring every verification with `term_end < today`: clear `user_id`/`verified_at`, claim → `expired`, role → citizen, bump `token_version`, audit `rep_verification_expired`; idempotent.
7. **Public badge.** Extend `GET /representatives/{id}` (TASK-09) with `verification`; never expose `user_id` or claimant identity.
8. **Ward dashboard service.** `src/modules/ward-dashboard/`: parameterised SQL for totals, category × age buckets, overdue (50), hotspots (`ST_SnapToGrid` on `ST_Transform(location::geometry, 32643)`), 12-week trend from `issue_events`; scope guard; 60/user/min limiter. Fixture-driven numbers in tests.
9. **CSV export.** Stream rows with the v1 CSV helper, formula-safe cells, column list from §5.3, date-range validation, limiter 10/user/h, audit `ward_export`.
10. **Representative actions.** Register a pre-transition hook in TASK-06's status service: when `actor_role='representative'`, enforce scope and the §5.3 rule table, and `ELECTION_MODE_FROZEN` if a note is present in election mode. Add `POST /staff/issues/{id}/comments`. `GET /staff/ward/issues` returns `allowedActions` computed by the same rule function.
11. **Messages inbox (P2).** On relay send (TASK-09 sender) generate `reply_token` and set Reply-To; inbox list/detail/reply endpoints; `POST /webhooks/mail-inbound` with HMAC check (constant-time compare), token lookup, quote stripping, update status `replied`, notify citizen; `GET /me/messages`. Bodies never logged.
12. **API tests.** Write T-11-01…T-11-16 (§8) in `apps/api/test/representatives/*.test.ts` against the test DB from TASK-01's harness; run in CI.
13. **Flutter: claim flow.** `features/representatives/claim/` (data, application, presentation): two steps + done on `StepScaffold`, sign-in gate return path, evidence upload with retry, error mapping by code; Me screen claims row; profile badge widget `VerifiedRepBadge`.
14. **Flutter: staff claims.** Add `/staff/claims` and `/staff/claims/:id` to TASK-10's staff router and side navigation (admin, moderator), approve/reject dialogs with validation, revoke action on representative detail.
15. **Flutter: ward dashboard.** `features/staff/ward_dashboard/`: provider with last-good cache, ward switcher, stat tiles, category × age table, overdue list, hotspot map (reuse TASK-07 map widget with circle layer) plus accessible list, trend chart with "Show as table" toggle, CSV download (web: browser download; app: share sheet). Neem visuals per §5.4 through TASK-03 tokens only.
16. **Dashboard motion (REQ-F-066).** Reuse TASK-09's `ScorecardStatTile`, `ScorecardBar` and `SeenOnce` (extend, don't copy, if a variant is needed — e.g. vertical bars for the trend); keys `ward-dash-<wardId>-<metric>`; bars triggered on first visibility; reduced-motion branch from TASK-03's resolved `reduceMotion` flag; confirm TASK-10's forbidden-motion scan allows only `features/staff/ward_dashboard/**`; run the no-`Duration(`-literal test.
17. **Flutter: ward issues and messages.** `/staff/ward/issues` with action sheet driven by `allowedActions`; `/staff/messages` list/detail/reply (P2); `/me/messages` (P2).
18. **ARB and Gujarati.** Add every new string to `app_en.arb` and `app_gu.arb`; error-code keys for the six new codes.
19. **Widget tests.** W-11-01…W-11-08 (§8).
20. **Manual checks.** M-11-01…M-11-10 on the emulator and Flutter web (motion recordings to `docs/demo/v2-evidence/motion/`); record evidence in the coverage matrix.

## 7. Acceptance Criteria

### 7.1 Behavioral

**AC-1** — Claim submitted with evidence
- **Given** a signed-in citizen whose OTP phone equals the seeded corporator's `public_phone`
- **When** they open the Paldi corporator's profile, tap "Claim this profile", upload 2 evidence photos and tap "Send claim"
- **Then** 201 `{claimId, status:"pending"}`, the claim row has `otp_verified=true`, `phone_match=true`, 2 evidence photos with purpose `rep_evidence`, the done screen shows, and Me lists the claim as "Waiting for review"
- **And** a second claim for the same record returns 409 `CLAIM_ALREADY_PENDING`; a 4th claim in a day returns 429

**AC-2** — Claim guards
- **Given** a representative record whose `term_end` is in the past, a moderator account, and a visitor
- **When** each tries to claim
- **Then** respectively 422 `REPRESENTATIVE_TERM_ENDED`, 409 `ROLE_CONFLICT`, and the sign-in gate (no request without a session)

**AC-3** — Admin approves; badge appears
- **Given** a pending claim
- **When** an admin opens `/staff/claims/:id`, views the evidence and approves with method "Certificate of election"
- **Then** the claim is `approved`, `representatives.user_id`/`verified_at`/`verified_method` are set, the user's role is `representative`, other pending claims for that record are rejected, the claimant gets a push + inbox notification, an audit line `rep_claim_decided` (actor, role, target, decision, method — no text) exists, and `GET /representatives/{id}` shows `verification.status="verified"` with method, date and `validUntil = term_end`; the profile shows the "Verified representative" badge

**AC-4** — Reject and reviewer limits
- **Given** a pending claim
- **When** a moderator tries to decide, and an admin rejects without a reason, then with reason "Document unreadable"
- **Then** the moderator gets 403 and sees the read-only notice; the reason-less reject returns 400; the valid reject sets `rejected`, notifies the claimant with the reason, and the claimant can submit a new claim

**AC-5** — Automatic expiry at term end and revocation
- **Given** a verified representative with an open staff session and `term_end` = yesterday
- **When** the next staff request is made, and then `npm run reps:expire` runs twice
- **Then** the request is refused (no access after term end even before the job), the job sets the claim `expired`, clears the link, sets the role to `citizen`, bumps `token_version` (old token → 401 `TOKEN_REVOKED`), the badge shows "Verification ended with the term", and the second run changes nothing
- **And** an admin "Revoke verification" with a reason has the same effect immediately and is audited

**AC-6** — Ward dashboard numbers
- **Given** the fixture ward with known issues (3 open aged 2 days, 4 aged 15 days, 2 aged 45 days across 2 categories; 3 overdue; 1 hidden; 1 rejected)
- **When** the verified corporator opens `/staff/ward`
- **Then** totals, the category × age table (0–7 / 8–30 / > 30) and the overdue list match the fixture exactly, hidden/rejected issues are excluded, the hotspot list contains the seeded cluster, the trend shows 12 weeks, and no reporter identity or phone appears in the response

**AC-7** — Dashboard scope
- **Given** the Navrangpura corporator
- **When** they request the Vasna dashboard, export or issue list
- **Then** each returns 403 `WARD_OUT_OF_SCOPE`, and the ward switcher lists only Navrangpura; an MLA sees exactly the wards mapped to their constituency; moderators and admins can open any ward

**AC-8** — CSV export
- **Given** the corporator's ward with issues, one of whose description starts with `=`
- **When** "Download CSV" is used for the last 90 days
- **Then** the file has exactly the §5.3 columns in order, one row per issue in range, no phone/name/reporter/description columns, cells are formula-safe, an audit line `ward_export` with row count exists, and the 11th export within an hour returns 429

**AC-9** — Acknowledge, mark fixed, comment within scope
- **Given** a `reported` issue in the corporator's ward
- **When** they tap "Acknowledge", then "Mark fixed" with an after photo, then "Add comment"
- **Then** the issue moves `reported → acknowledged → marked_fixed` with `issue_events` rows (`actor_role='representative'`), followers are notified (TASK-06), the comment appears as an event, and each action is audited without note text
- **And** the same actions on an issue in another ward return 403 `WARD_OUT_OF_SCOPE`

**AC-10** — Never verify or close
- **Given** a verified representative and a `marked_fixed` issue in their ward
- **When** they call `POST /issues/{id}/status` with `verified`, `rejected`, `in_progress` or `merged`, or `POST /issues/{id}/verifications`, or any `/staff/issues/{id}/reject|merge|hide|recategorise`
- **Then** every call returns 403 and the issue is unchanged; the UI never shows these actions (`allowedActions` excludes them)

**AC-11** — Election mode freezes authored content
- **Given** election mode on for the corporator's ward (TASK-09)
- **When** they add a comment, mark fixed with a note, reply in-app, and acknowledge without a note
- **Then** the comment, the note and the in-app reply return 409 `ELECTION_MODE_FROZEN` and the UI shows "Election mode is on. Comments and updates are paused."; the note-less acknowledge succeeds; existing comments remain visible; the dashboard shows the election banner and contains no comparison with other wards

**AC-12** — Neutrality
- **Given** two seeded corporators of different parties
- **When** their profiles, badges, dashboards and staff screens are compared
- **Then** layout, features and colours are identical, party appears only as plain text on the profile (TASK-09), and no screen ranks or compares representatives or wards

**AC-13** — Relayed-messages inbox and reply tracking (P2)
- **Given** 3 relayed messages to the corporator, one from a citizen who opted to share their phone
- **When** the corporator opens `/staff/messages`, reads one, replies in-app to another, and the third is answered by email (signed inbound webhook to `reply+<token>@…`)
- **Then** the inbox shows "A resident of {ward}" for each, the shared phone only on the opted-in message, unread state clears on open, both replies set `status='replied'` with `reply_channel` `in_app` / `email`, quoted history is stripped, the citizens are notified and see the reply in `/me/messages`; a webhook with a bad signature returns 401 and changes nothing; message bodies never appear in logs

**AC-14** — Dashboard numbers count up and bars grow on first view only
- **Given** the verified corporator of AC-6 with animations on, scope over ward 12 and ward 13
- **When** they open `/staff/ward` for ward 12, scroll to the trend chart, pull to refresh, switch to ward 13, switch back to ward 12, and toggle "Show as table" and back
- **Then** on the first view of ward 12 the four stat tiles count up from 0 to the AC-6 fixture values over `countUp` (integers only) and the 12 trend bars and category-total bars grow from 0 over `long` when scrolled into view; ward 13 animates once on its first view; refresh, returning to ward 12 and the table toggle show final values with no replay; the tiles and bars are the TASK-09 `ScorecardStatTile`/`ScorecardBar` widgets; the rest of the console changes with `short` fades only

**AC-15** — Dashboard motion with reduced motion
- **Given** the system "Remove animations" setting on (and separately the in-app Animations switch off)
- **When** the AC-14 steps are repeated
- **Then** every number and bar shows its final value in the first frame, the numbers match AC-6 exactly, and no count-up or growth runs

**AC → Requirement**

| AC | Requirements |
|---|---|
| AC-1, AC-2, AC-3, AC-4, AC-5 | REQ-F-053 |
| AC-6, AC-7, AC-8, AC-12 | REQ-F-054 |
| AC-9, AC-10, AC-11 | REQ-F-055 |
| AC-13 | REQ-F-056 |
| AC-14, AC-15 | REQ-F-066 |

### 7.2 Non-Functional Checklist

- [ ] Every new screen has loading (skeleton), empty, error ("Try again"), offline and unauthorised states
- [ ] All strings in `app_en.arb` and `app_gu.arb`; six new error codes mapped; Gujarati renders without clipping at 2.0× font
- [ ] TalkBack: badge reads "Verified representative, checked on {date}"; chart has a table alternative; hotspot map has a list alternative; dialogs trap focus
- [ ] 48 dp targets; status chips icon + word; no colour literal outside the theme; no party colours or logos
- [ ] Evidence photos never reachable without an admin token; `Cache-Control: no-store`; not attached to any issue; 90-day deletion query provided to TASK-13
- [ ] No phone, reporter identity, note text or message body in dashboard responses, CSV, audit lines or logs (redaction test)
- [ ] All SQL parameterised; dashboard p95 < 400 ms on pilot-size seed (5 wards × 500 issues)
- [ ] Scope check and term check happen server-side on every representative endpoint; UI hiding is not relied on
- [ ] Decide/expire/revoke run in single transactions; `reps:expire` idempotent
- [ ] Webhook signature compared in constant time; unknown tokens ignored without detail
- [ ] Neem visuals only (tokens, Baloo Bhai 2 numbers/titles, Mukta Vaani body, radii 14/18/24/pill, Rounded icons, no `sunrise`)
- [ ] REQ-F-066 motion uses `SaartheeMotion` tokens via the TASK-09 shared widgets; first view only; only transform/opacity animated; reduced motion shows final values at once; no `Duration(` literals

## 8. Validation & Testing

| Level | ID | What to test | Proves |
|---|---|---|---|
| Static | S-11-01 | `npm run typecheck && npm run lint` (api); `dart format --set-exit-if-changed . && dart analyze` (mobile) | all |
| API automated | T-11-01 | Claim happy path: 201, row fields, `phone_match` true/false cases, photos purpose check | AC-1 |
| API automated | T-11-02 | Claim guards: pending duplicate 409, verified 409, term ended 422, staff `ROLE_CONFLICT`, 4th/day 429, foreign photo 422 | AC-1, AC-2 |
| API automated | T-11-03 | Decide approve: transaction effects, role change, other pending rejected, notification enqueued, audit line shape | AC-3 |
| API automated | T-11-04 | Decide reject/permissions: moderator 403, missing reason 400, evidence endpoint admin-only | AC-4 |
| API automated | T-11-05 | Expiry: request-time block, `reps:expire` effects, idempotency, token_version bump → 401; revoke | AC-5 |
| API automated | T-11-06 | Dashboard numbers against the fixed fixture (buckets, overdue, exclusions, trend 12 weeks, hotspots) | AC-6 |
| API automated | T-11-07 | Scope: corporator other ward 403 on dashboard/export/list; MLA constituency wards; moderator any ward | AC-7 |
| API automated | T-11-08 | CSV: columns/order, formula-safe cell, no PII columns, audit, 11th/h 429 | AC-8 |
| API automated | T-11-09 | Representative transitions: allowed table, `issue_events` actor_role, comment endpoint | AC-9 |
| API automated | T-11-10 | Forbidden transitions and staff tools: verified/rejected/in_progress/merged/verifications/hide → 403 | AC-10 |
| API automated | T-11-11 | Election mode: comment/note/in-app reply 409, note-less acknowledge 200 | AC-11 |
| API automated | T-11-12 | Inbox: list/detail scope (other rep 403), read state, in-app reply, phone only when shared | AC-13 |
| API automated | T-11-13 | Inbound webhook: valid HMAC → replied/email, quote stripping, bad signature 401, unknown token ignored | AC-13 |
| API automated | T-11-14 | Redaction: log capture during claim, comment, reply, export contains no phone, note or body | AC-8, AC-13 |
| API automated | T-11-15 | Public `GET /representatives/{id}` verification block; no `user_id` leaked | AC-3, AC-12 |
| API automated | T-11-16 | Dashboard and profile payloads identical in shape for two representatives of different parties | AC-12 |
| Flutter widget | W-11-01 | `VerifiedRepBadge` verified / expired / unverified with semantics labels, en + gu | AC-3, AC-5 |
| Flutter widget | W-11-02 | Claim step 1: evidence required, upload retry, offline banner; step 2 error summary focus on 409 | AC-1, AC-2 |
| Flutter widget | W-11-03 | Claims review: approve dialog needs method, reject needs reason, moderator read-only | AC-3, AC-4 |
| Flutter widget | W-11-04 | Dashboard: renders fixture JSON (table, overdue, trend table toggle), empty and error states, election banner | AC-6, AC-11 |
| Flutter widget | W-11-05 | Ward issues action sheet shows only `allowedActions` | AC-9, AC-10 |
| Flutter widget | W-11-06 | Messages inbox unread dot, reply field limit, "Replied by email" line | AC-13 |
| Flutter widget | W-11-07 | Dashboard motion with fixture JSON: at t=0 tiles read 0, mid-`SaartheeMotion.countUp` an integer between 0 and the value, after it the AC-6 value; trend bars at scale 0 then full after `SaartheeMotion.long` once visible; refresh / ward switch back / table toggle rebuild shows final values in one frame; ward 13 animates once | AC-14 |
| Flutter widget | W-11-08 | Reduced-motion variant (`MediaQuery(disableAnimations: true)` and the in-app switch): after one `pump()` all tiles and bars are final and equal the fixture | AC-15 |
| Manual | M-11-01 | Emulator: sign in as seeded citizen → claim Paldi corporator with 2 photos → done → Me shows pending | AC-1 |
| Manual | M-11-02 | Flutter web console as admin: review evidence, approve; app profile shows badge | AC-3 |
| Manual | M-11-03 | Set `term_end` to yesterday via SQL, make a staff request, run `npm run reps:expire` twice | AC-5 |
| Manual | M-11-04 | Corporator on web console: dashboard numbers vs `psql` hand count; switch ward list; try Vasna URL | AC-6, AC-7 |
| Manual | M-11-05 | Download CSV, open in Sheets: columns, `=` cell shown as text | AC-8 |
| Manual | M-11-06 | Acknowledge → mark fixed with after photo → comment; citizen device receives push | AC-9 |
| Manual | M-11-07 | Turn election mode on (TASK-09 setting), try comment and note; TalkBack and 2.0× font on dashboard and claim | AC-11, AC-12 |
| Manual | M-11-08 | `scripts/mail-inbound-sim.ts` reply; citizen sees reply in `/me/messages` | AC-13 |
| Manual | M-11-09 | Emulator recording (`adb shell screenrecord /sdcard/t11-ward-dashboard.mp4`, `adb pull` to `docs/demo/v2-evidence/motion/`): first view of ward 12 (count-up, bars), refresh, ward switch and back; Chrome screen capture of the web console saved alongside | AC-14 |
| Manual | M-11-10 | Repeat M-11-09 with "Remove animations" on and with the in-app switch off; `t11-reduced-motion.mp4` | AC-15 |

## 9. Deliverables

- Migration `<timestamp>_v2_rep_claims_dashboard`, updated Prisma schema and `rep_scope_wards_v`.
- API modules `rep-claims`, `ward-dashboard`, `rep-messages` (P2), webhook `mail-inbound` (P2), scope helper, TASK-06 status hook; six error codes; audit actions; env vars.
- Scripts `reps:expire` and `mail-inbound-sim` (dev).
- Flutter: claim flow, verified badge, Me claims row, staff claims screens, ward dashboard, ward issues, messages inbox (P2), `/me/messages` (P2); ARB keys in English and Gujarati.
- Seed additions (claims, expired verification, messages) — fictional data only.
- Dashboard motion (REQ-F-066) through TASK-09's shared scorecard widgets; motion recordings in `docs/demo/v2-evidence/motion/`.
- Vitest suites T-11-01…16 and widget tests W-11-01…08 passing in CI.
- Coverage matrix rows REQ-F-053…056 and REQ-F-066 with evidence.

## 10. Files Expected to Change

Prediction only — exact paths may differ.

| Path | Change |
|---|---|
| `apps/api/prisma/migrations/<timestamp>_v2_rep_claims_dashboard/migration.sql`, `apps/api/prisma/schema.prisma` | New / Modified |
| `apps/api/prisma/seed*.ts` | Modified (claims, messages fixtures) |
| `apps/api/src/modules/{rep-claims,ward-dashboard,rep-messages,webhooks}/` | New |
| `apps/api/src/modules/representatives/` (TASK-09) | Modified (scope helper, verification block, Reply-To) |
| `apps/api/src/modules/issues/` (TASK-06 status service) | Modified (representative pre-transition hook) |
| `apps/api/src/lib/errors/index.ts`, `src/lib/audit/index.ts`, `src/config/` | Modified |
| `apps/api/scripts/reps-expire.ts`, `apps/api/scripts/mail-inbound-sim.ts`, `apps/api/package.json` | New / Modified |
| `apps/api/test/representatives/*.test.ts`, `apps/api/test/fixtures/ward-dashboard.ts` | New |
| `apps/mobile/lib/features/representatives/claim/`, `.../widgets/verified_rep_badge.dart` | New |
| `apps/mobile/lib/features/staff/{claims,ward_dashboard,ward_issues,messages}/` | New |
| `apps/mobile/lib/core/widgets/scorecard/` (TASK-09; extended only if a variant is needed) | Modified |
| `docs/demo/v2-evidence/motion/t11-*.mp4` | New |
| `apps/mobile/lib/features/me/` (claims row, messages) | Modified / New |
| `apps/mobile/lib/router/` (staff and citizen routes) | Modified |
| `apps/mobile/lib/core/l10n/app_en.arb`, `app_gu.arb` | Modified |
| `apps/mobile/test/features/representatives/*_test.dart`, `apps/mobile/test/features/staff/*_test.dart` | New |
| `apps/api/.env.example` | Modified |

## 11. Related Documentation

- `docs/v2/saarthee-v2-spec.md` Spec §3 — roles; representative capabilities.
- Spec §5 — state machine and who may mark fixed.
- Spec §6 — `representatives`, `rep_claims`, `rep_messages` columns.
- Spec §7 — Representatives and Staff endpoint groups (`/representatives/{id}/claims`, `/staff/rep-claims/{id}/decide`, `/staff/ward-dashboard`), rate limits.
- Spec §8 — `/staff/*` routes.
- Spec §11 — privacy (no reporter identity), neutrality, election mode.
- `docs/v2/design-system.md` DS §2 (Neem tokens, status colours, neutral palette), DS §3 (typography), DS §4 (radii, icons), DS §5 (representative row, list rows, stat tiles, banners), DS §6 (Motion: Scorecard and dashboards, Staff console, rules), DS §7 (accessibility), DS §9 (representative screens).
- `docs/tasks-v2/TASK-03-design-system-shell.md` (`SaartheeMotion`, `CountUp`), `TASK-09-representatives-my-ward.md` §5.4 Motion (shared scorecard widgets), `TASK-10-staff-console.md` (`StaffMotionScope`).
- `docs/tasks-v2/TASK-06-*.md`, `TASK-09-*.md`, `TASK-10-*.md` — contracts this task extends.

## 12. Risks & Considerations

| Risk | Impact | Mitigation |
|---|---|---|
| Impersonation: someone claims a representative's profile | Loss of trust, misuse of ward actions | Admin evidence review always required; phone match is only a signal; false-claim warning and suspension; revoke action; audit trail |
| Representative marks issues fixed that are not fixed | Inflated performance | They can never verify; citizen verification and reopen window (TASK-06) decide; dashboard shows verified separately from marked fixed |
| Political misuse during elections | Neutrality complaints, legal risk | Election mode freeze, no rankings, identical treatment; legal review (summary Open Question 6) before pilot |
| Dashboard queries slow on PostGIS hotspots | Poor console UX | GIST index from TASK-01, cap hotspots at 30, p95 target checked on pilot-size seed |
| Inbound email provider not chosen | P2 reply tracking delayed | In-app reply works without it; webhook behind a driver; defer REQ-F-056 email half with a recorded decision if needed |
| Expired verification still active between job runs | Out-of-term actions | Request-time term check in the scope helper, not only the job |
| Evidence photos contain personal data | Privacy exposure | Admin-only endpoint, no-store, 90-day deletion, never attached to public issues |
| Dashboard count-up replays on polling or refresh | Distracting, numbers hard to read | `SeenOnce` keyed per ward; W-11-07 asserts no replay |
| TASK-09 widgets not yet landed or differ | Duplicate widgets | TASK-09 is a dependency; extend its widgets rather than copy |

## 13. Progress Status

**Current status:** Not Started

**Progress:** 0%

| Date | Progress | Commit |
|---|---|---|

## 14. Completion Checklist

- [ ] All implementation steps complete
- [ ] All behavioral acceptance criteria verified in the running application
- [ ] Non-functional checklist fully ticked
- [ ] Static checks pass and every AC verified by the checks in §8
- [ ] Automated tests added and passing
- [ ] Frontend and backend integrated end to end (no mocked data left in place)
- [ ] Error, loading, empty, and unauthorized states verified
- [ ] Code reviewed against the patterns established in earlier tasks
- [ ] Assumptions documented and, where possible, confirmed
- [ ] Coverage matrix rows for this task's requirements set to Pass with evidence (`check_coverage.py --task TASK-11` shows 0 unverified)
- [ ] Task file progress log and status updated
- [ ] `00-task-summary.md` updated
- [ ] Committed as `V2-TASK-11: …`
- [ ] Validator passes
- [ ] Ward dashboard matches Neem v2.2 visuals (stat tiles, type, radii, Rounded icons)
- [ ] REQ-F-066 dashboard motion implemented with TASK-09's shared widgets and `SaartheeMotion` tokens; W-11-07 and W-11-08 pass
- [ ] Motion recordings saved to `docs/demo/v2-evidence/motion/` (M-11-09, M-11-10)
