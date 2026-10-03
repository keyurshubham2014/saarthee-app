# TASK-09: Representatives, My Ward and Message Relay

| Field | Value |
|---|---|
| Task ID | TASK-09 |
| Status | Not Started |
| Priority | P0 |
| Size | M |
| Depends On | TASK-02, TASK-04 |
| Blocks | TASK-11 |
| Requirement IDs | REQ-F-042, REQ-F-043, REQ-F-044, REQ-F-045, REQ-F-046, REQ-F-047, REQ-D-008, REQ-D-012, REQ-S-009, REQ-S-012 |
| Primary Spec Refs | Spec §2 (D2, D5), §3, §6 (`representatives` … `rep_messages`, `app_settings`), §7 (Representatives, Public stats, Staff, rate limits), §8 (`/ward*`, `/representatives/*`), §11 (neutrality, election mode); DS §2–§4 (Neem tokens, Baloo Bhai 2 / Mukta Vaani, radii, Rounded icons), §5 (Representative row, Stat tiles, Toast, Banners), §6 (Motion: My Ward, Scorecard and dashboards), §7 (accessibility), §8 (Find my corporators), §9 |
| Last Updated | 2026-10-03 |

## 1. Objective

Let any Amdavadi open **My Ward** and see who represents them — the four ward corporators, the MLA(s) and MP(s) — with only official or consented contact details, a source link and a "last checked" date for every entry. A signed-in citizen can send a message (optionally about an issue) that Saarthee emails to the representative's published address, with rate limits, a profanity screen and the citizen's phone hidden unless they choose to share it. Staff maintain the roster through a CSV import that requires a source URL per row and refuses personal numbers, plus CRUD for representatives and the ward → assembly-constituency mapping. A public ward scorecard (P1) shows how issues are handled, with a plain method note. An election mode, per city or per ward, freezes representative-authored content and hides the scorecard, with a banner. Motion follows DS §6: representative rows rise in with a stagger, "Message sent" is confirmed by a toast with a drawn check, and scorecard numbers count up and bars grow the first time they are seen — through shared scorecard widgets that TASK-11's dashboard reuses.

## 2. Scope

### In Scope
- Migration `<ts>_v2_representatives`: `representatives`, `representative_areas`, `assembly_constituencies`, `ward_constituency`, `rep_claims`, `rep_messages` (REQ-D-008).
- Migration `<ts>_v2_app_settings` **if TASK-10 has not created it yet**, using exactly the DDL in TASK-10 §5.2 (TASK-10 owns REQ-D-011); this task owns the `election_mode` key and its behaviour.
- Migration `<ts>_v2_ward_scorecard`: materialised view `ward_scorecard_mv` + hourly refresh job (REQ-D-012).
- CLI tools: `npm run reps:import -- --file <csv> [--dry-run]` and `npm run constituencies:import -- --file <csv> [--dry-run]`.
- Data work: compile the 2026–31 roster by hand for at least the 5 pilot wards (Paldi, Navrangpura, Vasna, Naranpura, Nava Vadaj — 20 corporators) plus all MLAs/MPs covering AMC wards, into `apps/api/data/representatives/` with a source URL on every row.
- API: `GET /wards/{id}/representatives`, `GET /representatives/{id}`, `POST /representatives/{id}/messages`, `GET /wards/{id}/scorecard`, `GET /settings/public`; staff CRUD `/staff/representatives`, `/staff/constituencies`, `PUT /staff/wards/{id}/constituencies`, `GET/PUT /staff/settings/election-mode`.
- Email delivery: `src/lib/mail` interface with `ses` (Amazon SES v2, ap-south-1) and `file` (local dev) drivers; outbox job sending queued relay messages with retry (TASK-11 adds per-message Reply-To and inbound reply tracking).
- Election-mode helper `isElectionMode(wardId)` and middleware `assertNotElectionFrozen(wardIdResolver)` for representative-authored writes (used by TASK-11).
- App: My Ward tab `/ward` and `/ward/:id`, `/representatives/:id`, `/representatives/:id/message` (+ "Message sent" toast), `/ward/:id/scorecard`, election banner; staff screens `/staff/representatives` (list, edit) mounted by TASK-10's shell.
- Fictional representatives in the v2 dev seed; tests.
- DS §6 motion owned here (attached to REQ-F-042, REQ-F-044, REQ-F-046): My Ward representative rows rise with `stagger`; "Message sent" toast with a drawn check (`MotionCheck`); scorecard numbers `CountUp` and percentage bars grow from 0 (`long`) on first view only; reduced-motion variants. Shared scorecard widgets `ScorecardStatTile` and `ScorecardBar` in `lib/core/widgets/scorecard/` for reuse by TASK-11 (REQ-F-066).

### Out of Scope
- Representative claim flow and verification — TASK-11 (this task only creates `rep_claims`).
- Representative inbox and reply tracking (REQ-F-056) — TASK-11.
- Representative-authored comments/updates and the ward dashboard — TASK-11 (must call `assertNotElectionFrozen`).
- Settings UI shell and its navigation — TASK-10 (calls this task's election-mode endpoint).
- Services and drives sections on My Ward — TASK-12 fills the slots this task leaves.
- Escalation ladder message composition — TASK-06 (opens `/representatives/:id/message?issueId=`).
- Final verification of pilot-ward rosters before launch — TASK-14 (REQ-O-011).
- Motion tokens and helpers (`SaartheeMotion`, `StaggeredColumn`, `MotionCheck`, `CountUp`, toast, reduced-motion switch) — TASK-03; dashboard motion — TASK-11 (REQ-F-066); frame-time audit — TASK-14 (REQ-N-013).

## 3. Prerequisites

- TASK-02: `wards` (number, names, zone, office_address, office_phone, `population` NULL), `zones`, `GET /wards/{id}`, ward picker.
- TASK-04: users/session (`requireUser`, `requireRole`), consents (`share_with_representatives` purpose), `ensureSignedIn()` sign-in-and-return, privacy registries `registerExportSection` / `registerErasureStep` (this task registers `rep_messages`), log redaction of `body`/`message` (REQ-S-015).
- TASK-03: Neem shell with My Ward tab placeholder, components (representative row base, stat tile, toast, banners), ARB; motion foundation — `SaartheeMotion` tokens (`lib/core/theme/motion.dart`), `animations` + `flutter_animate`, press-scale wrapper, haptics helper, `MotionCheck`, `CountUp`, `StaggeredColumn`, reduced-motion resolution.
- TASK-01: issues tables (for scorecard), test harness, v2 seed module. Job runner `src/jobs` (TASK-06 contract; created here if neither TASK-06 nor TASK-08 has landed).
- Env: `EMAIL_DRIVER=file|ses`, `EMAIL_FILE_DIR` (outside repo), `SES_REGION=ap-south-1`, `SES_FROM=relay@<domain>`, `EMAIL_OPS_ADDRESS`, `PUBLIC_WEB_BASE_URL`, `RELAY_PER_REP_DAILY=5`, `RELAY_PER_USER_DAILY=20`, `SCORECARD_WINDOW_DAYS=90`, `SCORECARD_MIN_SAMPLE=5`.
- Founder/ops action: verify the sending domain in SES (SPF, DKIM, DMARC) and request production access before staging sends real email.

## 4. Dependencies

| Task | Why it is required |
|---|---|
| TASK-02 | Wards and zones for areas and mapping; ward population; ward office details on My Ward |
| TASK-04 | Citizen sign-in for messages, consent records, export/deletion hooks, redaction |

## 5. Technical Context

### 5.1 Requirements Covered

| Req ID | Requirement | Source |
|---|---|---|
| REQ-F-042 | My Ward screen: four corporators, MLA, MP, ward office, scorecard link, services and drives for the ward | Spec §8 |
| REQ-F-043 | Representative profile: name (gu/en), role, party as plain text, term, office contact if published, source link, last checked date | Spec §6, D2 |
| REQ-F-044 | Message relay: citizen sends a message (optionally about an issue) that Saarthee emails to the representative; citizen phone hidden unless the citizen opts in | Spec D2, §7 |
| REQ-F-045 | Representative roster import tool (CSV with source URLs) and staff CRUD for representatives and ward–constituency mapping | Spec §6 |
| REQ-F-046 | Public ward scorecard: median days to acknowledge and to fix, verified %, reopen %, open backlog, reports per 1,000 residents, method note | Spec §7 |
| REQ-F-047 | Election mode per city or ward: freezes representative-authored content and hides comparative stats, with a banner | Spec §11 |
| REQ-D-008 | `representatives`, `representative_areas`, `assembly_constituencies`, `ward_constituency`, `rep_claims`, `rep_messages` tables | Spec §6 |
| REQ-D-012 | Ward scorecard computed by a SQL view or materialised view refreshed hourly | Spec §7 |
| REQ-S-009 | Message relay rate-limited (5/day per representative), profanity screen, citizen phone hidden by default | Spec D2 |
| REQ-S-012 | Representative data shows only office or consented contacts; personal numbers never imported | Spec D2 |

### 5.2 Data Contracts

Migration `<ts>_v2_representatives` (enums `rep_role` = `corporator|mla|mp`, `rep_message_status` = `queued|sent|failed|replied`, `rep_claim_status` = `pending|approved|rejected`):

| Table | Columns and rules |
|---|---|
| `representatives` | `id` uuid PK; `name_en` 2–120, `name_gu` 2–120 (NOT NULL); `role` rep_role; `party_text` ≤ 80 NULL (plain text, "Independent" allowed); `term_start` date, `term_end` date NULL (`CHECK term_end > term_start`); `public_phone` NULL — E.164 **landline only** at import (`CHECK (public_phone IS NULL OR public_phone ~ '^\+9179\d{8}$' OR contact_consent_at IS NOT NULL)`); `public_email` NULL (lower-case, ≤ 254); `contact_consent_at` NULL (set only by TASK-11 claim); `photo_url` NULL (unused in v2 — initials avatars); `source_url` NOT NULL `CHECK (source_url ~ '^https://')`; `last_verified_at` date NOT NULL; `user_id` NULL → users UNIQUE; `verified_at`, `verified_method` NULL; `is_active` bool default true; `created_at`, `updated_at`. UNIQUE `(role, lower(name_en), term_start)` (import upsert key) |
| `representative_areas` | `representative_id` → representatives ON DELETE CASCADE; `ward_id` NULL → wards; `assembly_constituency_id` NULL → assembly_constituencies; `CHECK (num_nonnulls(ward_id, assembly_constituency_id) = 1)`; corporators use `ward_id`, MLAs one AC, MPs one row per AC in their Lok Sabha seat; UNIQUE on the non-null pair; index `(ward_id)` |
| `assembly_constituencies` | `id` serial; `number` int UNIQUE (ECI AC number); `name_en`, `name_gu`; `pc_name_en`, `pc_name_gu` (Lok Sabha seat); `source_url` https |
| `ward_constituency` | `ward_id`, `assembly_constituency_id`, `source_url` https; PK `(ward_id, assembly_constituency_id)` (many-to-many: a ward can span ACs) |
| `rep_claims` | `id`, `representative_id`, `user_id`, `evidence_photo_ids` uuid[], `otp_verified` bool, `status` rep_claim_status default `pending`, `reviewer_id` NULL, `decided_at` NULL, `note` ≤ 500 NULL, `created_at` — created empty here, used by TASK-11 |
| `rep_messages` | `id`; `client_message_id` uuid UNIQUE (idempotency); `representative_id`; `citizen_id` NULL → users (NULL after account deletion); `issue_id` NULL → issues; `subject` 3–120; `body` 10–1,000; `share_phone` bool default false; `status` default `queued`; `attempts` int default 0; `provider_message_id` NULL; `sent_at` NULL; `created_at`; index `(citizen_id, representative_id, created_at)` |

`app_settings` (DDL owned by TASK-10 §5.2; created here only if absent): key `election_mode`, value JSON `{enabled: bool, scope: 'city'|'wards', wardIds: int[], from: ISO, to: ISO, note_en ≤ 200, note_gu ≤ 200}`. Active ⇔ `enabled && from ≤ now < to && (scope='city' || wardId ∈ wardIds)`.

Migration `<ts>_v2_ward_scorecard` — `ward_scorecard_mv` (UNIQUE index on `ward_id` so `REFRESH … CONCURRENTLY` works), over issues created in the last `SCORECARD_WINDOW_DAYS` (90), excluding `visibility='hidden'` and status `rejected`/`merged`:

| Column | Definition |
|---|---|
| `issues_reported` | count in window |
| `median_days_ack` | median of (first `issue_events.to_status='acknowledged'` − `created_at`) in days, 1 dp |
| `median_days_fix` | median of (first `to_status='marked_fixed'` − `created_at`) |
| `verified_pct` | verified ÷ (verified + reopened + marked_fixed older than 7 days) × 100 |
| `reopen_pct` | issues with any `to_status='reopened'` ÷ issues ever marked fixed × 100 |
| `open_backlog` | current status in (`reported`,`sent`,`acknowledged`,`in_progress`,`reopened`) — all time, not windowed |
| `reports_per_1000` | `issues_reported ÷ wards.population × 1000`, NULL if population unknown |
| `refreshed_at` | `now()` at refresh |

Medians and percentages are returned as `null` when their sample < `SCORECARD_MIN_SAMPLE` (5). Job `scorecard-refresh` hourly on the `src/jobs` runner.

CSV formats (UTF-8, header row required, unknown columns rejected):
- **Roster:** `name_en,name_gu,role,party_text,term_start,term_end,ward_number,ac_number,office_phone,public_email,source_url,last_verified_at`. Rules: `source_url` https and mandatory **per row**; `last_verified_at` ISO date not in the future; corporator → `ward_number` 1–48 required, `ac_number` empty; MLA → `ac_number`; MP → `ac_number` list `"44;45;46"`; `office_phone` must normalise to a 079 landline (`+9179XXXXXXXX`) — any 10-digit mobile (starting 6–9) **rejects the row** with "Mobile numbers are never imported. Use an official office landline or leave it empty."; ward may not exceed 4 active corporators. Dry run prints per-row `create|update|unchanged|error`; commit runs in one transaction and aborts on any error.
- **Constituencies:** `ac_number,ac_name_en,ac_name_gu,pc_name_en,pc_name_gu,ward_numbers,source_url` (`ward_numbers` `"9;10;11"`).

Roster sources (record in `apps/api/data/representatives/SOURCES.md`): corporators from the State Election Commission Gujarat AMC 2026 results (primary `source_url`), cross-checked against MyNeta affidavits; MLAs from ECI Gujarat 2022 results; MPs from ECI 2024 results; ward ↔ AC mapping from the Delimitation Order 2008 and AMC's ward list. Party exactly as printed in the result; no photos, no personal numbers.

### 5.3 API Contracts

| Method | Path | Auth | Request | Response | Errors | Rate limit |
|---|---|---|---|---|---|---|
| GET | `/wards/{id}/representatives` | None | — | `{ward:{id,number,nameEn,nameGu,zone,officeAddress,officePhone}, corporators:[RepSummary], mlas:[RepSummary], mps:[RepSummary], electionMode:{active, until, noteEn, noteGu}}` | 404 | 120/IP/min |
| GET | `/representatives/{id}` | None | — | `RepDetail` | 404 (inactive → 404) | 120/IP/min |
| POST | `/representatives/{id}/messages` | Citizen | `{clientMessageId uuid, subject 3–120, body 10–1000, issueId?, sharePhone bool}` | 202 `{messageId, status:'queued'}`; repeat `clientMessageId` → 200 same | 400 `VALIDATION_FAILED`, 401, 403 `CONSENT_REQUIRED`, 404, 422 `MESSAGE_LANGUAGE`, 422 `REP_NO_CONTACT`, 429 `RATE_LIMITED` (`Retry-After` to IST midnight) | 5/day per citizen per representative; 20/day per citizen |
| GET | `/wards/{id}/scorecard` | None | — | `{wardId, windowDays, refreshedAt, metrics:{issuesReported, medianDaysAck, medianDaysFix, verifiedPct, reopenPct, openBacklog, reportsPer1000}, population:{value, sourceNote}, hidden:false}` or `{hidden:true, reason:'election_mode', until}` | 404 | 120/IP/min |
| GET | `/settings/public` | None | — | `{electionMode:{active, scope, wardIds, until, noteEn, noteGu}}` (cached 60 s) | — | 120/IP/min |
| GET/POST | `/staff/representatives` | Admin | list filters `ward`, `role`, `q`, `active`; create body = roster fields + `areas` | list / 201 | 400, 403, 409 `REP_DUPLICATE` | 300/actor/min |
| PATCH/DELETE | `/staff/representatives/{id}` | Admin | partial; DELETE = set `is_active=false` | 200 | 400 (mobile number → `REP_PERSONAL_NUMBER`), 403, 404 | 300/actor/min |
| GET | `/staff/constituencies` | Admin, Moderator (read) | — | ACs with mapped ward numbers | 403 | 300/actor/min |
| PUT | `/staff/wards/{id}/constituencies` | Admin | `{items:[{acId, sourceUrl}]}` (1–4) | 200 | 400, 403, 404 | 300/actor/min |
| GET/PUT | `/staff/settings/election-mode` | GET Admin+Moderator, PUT Admin | election_mode JSON (§5.2); `to > from`, `to − from ≤ 120 days` | 200 current value | 400, 403 | 300/actor/min |

`RepSummary`: `id, nameEn, nameGu, role, partyText, wardNumber?, acName?, initials, canMessage, verified`. `RepDetail` adds `termStart, termEnd, officePhone (only if present), publicEmail (only if present), sourceUrl, lastVerifiedAt, areas`. Never returned publicly: `user_id`, `contact_consent_at`, claim data, message counts.

**Relay workflow:** validate → consent `share_with_representatives` active, else 403 `CONSENT_REQUIRED` → representative active with `public_email`, else 422 `REP_NO_CONTACT` → idempotency on `clientMessageId` → rate limits counted from `rep_messages` (IST day; DB-backed so restarts don't reset) → profanity screen on subject + body (word lists `src/lib/profanity/{en,gu,translit}.txt`, Unicode-normalised, whole-word match) → 422 `MESSAGE_LANGUAGE` "Your message contains words we can't send. Please edit it and try again." (nothing stored; log `relay_rejected_language` without text) → `issueId` must exist and be public → insert `queued` → outbox job `relay-send` (every 30 s + immediate attempt) sends via `src/lib/mail`; up to 3 attempts with backoff; then `failed` and ops alerted by log.
Email: From `Saarthee Relay <SES_FROM>`, To `public_email`, Reply-To `EMAIL_OPS_ADDRESS` (reply tracking is TASK-11), Subject `[Saarthee] Message from a resident of Ward <n> <name>: <subject>`; text + HTML body: message, issue link `PUBLIC_WEB_BASE_URL/issues/<id>` if given, phone **only if `share_phone`** ("The resident agreed to share their phone number: +91…"), otherwise "The resident chose not to share their phone number."; footer: DS §1 independence line + "Saarthee relays messages from residents. To stop receiving them, write to <ops address>." Citizen display name never included unless set; never the citizen's phone by default.
New error codes: `CONSENT_REQUIRED` 403, `REP_NO_CONTACT` 422 "We don't have an official email for this representative yet.", `MESSAGE_LANGUAGE` 422, `REP_DUPLICATE` 409, `REP_PERSONAL_NUMBER` 400 "Mobile numbers can't be saved here. Use an official office landline.", `ELECTION_MODE_FROZEN` 409 "Election mode is on. Comments and updates are paused until it ends." (same code and copy as TASK-11).

**Election mode:** `isElectionMode(wardId)` (cached 60 s, invalidated on PUT); `assertNotElectionFrozen(resolveWardId)` rejects **representative-role** writes of representative-authored content with 409 `ELECTION_MODE_FROZEN` (TASK-11 applies it to comments, notes on status changes, in-app replies). Effects owned here: scorecard hidden for affected wards; My Ward, representative profile and scorecard show the banner; staff (admin) corrections to the roster remain allowed and are audited. Citizen messages to representatives remain allowed.

### 5.4 UI Surfaces & States

| Route | Content | States |
|---|---|---|
| `/ward` (My Ward tab → home ward) and `/ward/:id` | Header: "Ward 12 · Paldi" + zone, "Change ward"; election banner if active; **Corporators** (4 representative rows: initials avatar, name in UI language with the other script below, "Corporator", party as plain text, "Message" button); **MLA** and **MP** sections (if the ward spans several ACs: "Your ward is in 2 assembly constituencies." and each MLA listed); **Ward office** (address, office phone with Call action); "Ward scorecard" row → scorecard; slots for Services and Drives (empty until TASK-12); app-bar action to Profile (`/me`) | no home ward → "Choose your ward" + picker; loading skeleton rows; fewer than 4 corporators → row "Seat details being checked"; no reps at all → "We're still adding representatives for this ward." + "Ward office" still shown; error "We couldn't load your ward." + "Try again"; offline: last cached ward |
| `/representatives/:id` | Avatar (initials), names gu + en, role line ("Corporator, Ward 12 Paldi" / "MLA, <AC>" / "MP, <seat>"), "Party: <text>", "Term: 2026–2031", office phone (only if published), "Message <name>" primary button, "Source: <domain> · Last checked 12 Sep 2026" link, "Verified by Saarthee" chip if `verified`, neutrality line "Saarthee is independent and treats all representatives the same." | no email → button disabled + "We don't have an official email for this representative yet."; election banner; 404 "This profile isn't available." |
| `/representatives/:id/message` (sign-in required, returns here) | "Message <name>"; "About an issue (optional)" (prefilled from `?issueId=`, or pick from my reports); Subject; Message 0/1000; checkbox (unchecked) "Share my phone number with <name> so their office can call me back"; note "We'll email your message to <name>'s official address. Your phone number stays hidden unless you tick the box. Representatives aren't required to reply."; Kindness prompt "Keep it respectful. Messages with abusive language are not sent."; "Send message" | first send without consent → consent sheet (`share_with_representatives`, versioned text) → continue; in-flight button progress; errors: rate limit "You've sent 5 messages to this representative today. You can send more tomorrow.", language, no contact, offline "You're offline. Your message hasn't been sent." (text kept in the form) |
| "Message sent" toast (on 202, after returning to `/representatives/:id`) | DS §5 toast: `primaryDark` background, radius 18, white text "Message sent. We've emailed it to <name>'s office.", leading check drawn by `MotionCheck`, 4 s; live-region announcement of the same text | repeat send (200 same id) → same toast once |
| `/ward/:id/scorecard` | "Ward 12 scorecard · Last 90 days · Updated 10:00"; six `ScorecardStatTile`s (DS §5 stat tile: `surfaceAlt`, radius 14, number in numeric style — Baloo Bhai 2 20/24 tabular — and label in bodySmall Mukta Vaani); the two percentages also show a `ScorecardBar` (`primary` fill on a `surfaceAlt` track, radius pill) with plain labels ("Median days to acknowledge", "Median days to fix", "Fixes verified by residents", "Reopened after fixing", "Open issues now", "Reports per 1,000 residents"); "How we calculate this" (expandable method note: "Based only on reports made in Saarthee, not AMC's records. Medians use reports from the last 90 days. A fix counts as verified when a resident confirms it with a photo. Reports per 1,000 residents uses the ward population from <source>, where available. Figures need at least 5 reports.") | small sample tile "Not enough reports yet"; population missing "—" + note; election mode: banner + "The scorecard is paused during the election period."; loading, error, offline (cached) |
| `/staff/representatives`, `/staff/representatives/:id` | List with filters (ward, role, active), "Last checked" column (older than 180 days highlighted "Needs re-check"); edit form with every roster field, area picker, validation messages from §5.3; constituency mapping editor on the ward page | 403 page; error summary; in-flight states |

Visuals (Neem v2.2, all via TASK-03 tokens): white app bar with left-aligned headlineSmall title (Baloo Bhai 2 24/32); section titles in titleLarge (Baloo Bhai 2 19/26); representative rows ≥ 72 dp with a 40 dp initials avatar (`primaryContainer` circle, `primaryDark` initials), name in titleMedium (Mukta Vaani), "Message" as an outlined secondary button (1.5 px `borderStrong`, `primary` text, radius 14); cards radius 18; Material Symbols Rounded icons (`call`, `mail`, `how_to_vote`, `verified`); no `sunrise` on these screens.

#### Motion (DS §6 "My Ward", "Scorecard and dashboards")

All durations and curves come from TASK-03 `SaartheeMotion`; no `Duration(` literal in `lib/features/**`. With reduced motion (system "Remove animations" or the in-app Animations switch) each item becomes an instant change or a ≤ 100 ms cross-fade with identical content.

| Moment | Behaviour | Tokens / helper | Reduced motion | Requirement |
|---|---|---|---|---|
| My Ward rows | Header, corporator rows, MLA/MP rows and the ward-office card rise (`rise` 14 dp + fade) with `stagger` 60 ms, max 6 staggered (later rows appear with the 6th), on the first load of a ward in the session; switching tabs and back does not replay; changing ward plays it once for the new ward | `StaggeredColumn`, `stagger`, `rise` | Rows shown at once | REQ-F-042 |
| "Message sent" | Toast slides up with `springIn`; its check is drawn by `MotionCheck` (`drawCheck`: 450 ms stroke, starting 150 ms after the toast); success haptic via the haptics helper | `springIn`, `drawCheck`, `MotionCheck`, haptics helper | Toast and full check appear at once | REQ-F-044 |
| Scorecard numbers | Each metric counts up from 0 to its value (`countUp`, 600 ms, `easeOutCubic`, integers only; one-decimal medians count the integer part then show the decimal at the end) the first time the tile becomes visible | `CountUp` | Final value shown at once | REQ-F-046 |
| Scorecard bars | Percentage bars grow from 0 to their value over `long` (transform `scaleX` from the start edge, clipped — no layout animation) the first time seen; never on rebuild, refresh or scroll back | `long` | Bars at full value at once | REQ-F-046 |

"First view" is tracked per (ward id, screen) in a session-scoped `SeenOnce` registry inside the shared scorecard widgets (`ScorecardStatTile(animateKey:)`, `ScorecardBar(animateKey:)`), so pull-to-refresh, hourly data changes and rebuilds show the new number without replaying; TASK-11 passes its own keys.

Election banner (DS §5 Banners, `warning` tint, icon `how_to_vote`): "Election period until <date>. Some representative information is paused." / Gujarati key `electionBannerText`. ARB prefixes: `myWard*`, `rep*`, `relay*`, `scorecard*`, `electionBanner*`, `staffReps*`.

### 5.5 Permissions & Roles

| Action | Visitor | Citizen | Moderator | Admin | Representative |
|---|---|---|---|---|---|
| View My Ward, profiles, scorecard | ✅ | ✅ | ✅ | ✅ | ✅ |
| Send relay message | ❌ (sign-in) | ✅ (consent) | ✅ | ✅ | ✅ (as a citizen) |
| Import roster / CRUD representatives / edit mapping | ❌ | ❌ | read only | ✅ | ❌ |
| Set election mode | ❌ | ❌ | read only | ✅ | ❌ |
| Author representative content while election mode is active | — | — | — | — | ❌ 409 |

Staff endpoints use TASK-04's `requireRole(...roles)` with the staff extension (contract in TASK-08 §5.5 / TASK-10 §5.3; made here if this task lands first). Audit actions: `rep_created`, `rep_updated`, `rep_deactivated`, `rep_roster_imported` (counts only), `ward_constituencies_updated`, `election_mode_set`.

### 5.6 Assumptions

- ASSUMPTION: Email provider is **Amazon SES v2 in ap-south-1 (Mumbai)** — low cost (about US$0.10 per 1,000), India region for personal data, mature SPF/DKIM, and SES inbound receiving can feed TASK-11's reply webhook; behind `src/lib/mail` so it can be swapped (Resend/Postmark) without changing callers. Spec D2 says "email" without naming a provider.
- ASSUMPTION: Rate limits are 5/day per citizen per representative (Spec §7) **plus** 20/day per citizen overall to stop spraying many representatives; days are IST calendar days.
- ASSUMPTION: The importer accepts only 079 landlines as `office_phone`; every mobile number is refused, even if it is called an office number, because it cannot be told apart from a personal number. Consented mobiles come only through the TASK-11 claim (`contact_consent_at`).
- ASSUMPTION: Avatars are initials only; no photos are copied from official sites (copyright and hot-linking).
- ASSUMPTION: Election mode hides the whole ward scorecard for affected wards (public ward scorecards invite comparison) and blocks new or edited representative-authored text (TASK-11 applies the same rule); existing content stays visible; citizen messages still go through. Legal review pending (Open Question 6).
- ASSUMPTION: `app_settings` is created by whichever of TASK-09/TASK-10 lands first, from the single DDL in TASK-10 §5.2.
- ASSUMPTION: Scorecard window 90 days, minimum sample 5; population from the TASK-02 `wards.population` column (Census-based, may be NULL) with the source shown in the method note.
- ASSUMPTION: Scorecard route `/ward/:id/scorecard` (DS §9 lists the screen; Spec §8 has no route).
- ASSUMPTION: Replies from representatives go to the ops mailbox until TASK-11 adds the per-message `reply+<token>@MAIL_REPLY_DOMAIN` Reply-To and inbound tracking; the citizen is told replies are not guaranteed.
- ASSUMPTION: The separate "Message sent" screen is replaced by the DS §6 toast with a drawn check after returning to the profile; the "not required to reply" note moves into the message form. DS §6 lists the toast; Spec §8 does not name a sent screen.
- ASSUMPTION: Scorecard "bars" are shown for the two percentage metrics (verified %, reopened %); the other tiles are numbers only. DS §6 says "bars grow" without listing which metrics.
- ASSUMPTION: Scorecard first-view tracking is per app session (cleared on process restart), not persisted.
- ASSUMPTION: `rep_messages` are kept 1 year, included in `/me/export` (via `registerExportSection`), and set `citizen_id = NULL` on account deletion (via `registerErasureStep`; body kept for the representative's record) — spec silent; legal review.

## 6. Implementation Steps

1. **Confirm contracts** from TASK-02/04 (ward fields, consent purposes, `requireUser`/`requireRole`, privacy registries) and TASK-06/08/10 (`src/jobs` runner, `app_settings` DDL, staff extension of `requireRole`); create the shared ones if absent.
2. **Migrations** `<ts>_v2_representatives` (+ `<ts>_v2_app_settings` if absent) with all CHECKs and indexes; Prisma models; `prisma generate`, typecheck.
3. **Seed.** Fictional representatives (4 corporators for each of the 5 pilot wards with `term_start`/`term_end`, 3 MLAs, 1 MP), fictional ACs and mapping, election mode off; clearly marked "Sample data" (TASK-11 seeds claims on top).
4. **Import tools.** `scripts/import-representatives.ts` and `scripts/import-constituencies.ts`: CSV parse (*candidate* `csv-parse`), row validation per §5.2, dry-run report, single-transaction commit, upsert by key, audit line with counts. Unit tests with good/bad fixtures.
5. **Compile the real roster** for the 5 pilot wards + all MLAs/MPs over AMC wards and the full ward ↔ AC mapping into `apps/api/data/representatives/{roster-2026.csv,constituencies.csv,SOURCES.md}`; every row has a primary source URL and `last_verified_at`; second person spot-checks 10 rows. Import on staging (not into local dev with real citizens).
6. **Public API.** `src/modules/representatives`: ward representatives, detail (no hidden fields), `GET /settings/public`.
7. **Election mode.** `src/modules/settings/electionMode.ts` (read/validate/cache), staff GET/PUT, `assertNotElectionFrozen` middleware + unit test with a test-only route.
8. **Mail lib.** `src/lib/mail` interface `send({to, subject, text, html, tag}) → {providerMessageId}`; drivers `file` (writes `.eml` to `EMAIL_FILE_DIR`) and `ses` (*candidate* `@aws-sdk/client-sesv2`); startup check of env.
9. **Relay.** Profanity lists + matcher (`src/lib/profanity`), relay service per §5.3, outbox job `relay-send`, templates (text + HTML, escaped), redaction of `body`/`subject` in logs; register `rep_messages` export section and erasure step.
10. **Staff CRUD.** `src/modules/staff-representatives`: list/create/update/deactivate, mapping PUT, mobile-number guard shared with the importer.
11. **Scorecard.** `<ts>_v2_ward_scorecard` materialised view + unique index; job `scorecard-refresh` (hourly, `CONCURRENTLY`); `GET /wards/{id}/scorecard` with sample suppression and election hiding.
12. **API tests** T-09-01…T-09-14 green; manual M-09-01, M-09-02.
13. **App data + providers.** `features/ward/{data,application}`: ward reps, rep detail, scorecard, public settings (election mode), relay submit with `clientMessageId` kept until success.
14. **Screens.** `/ward`, `/ward/:id` (replace TASK-03 placeholder), `/representatives/:id`, message form + "Message sent" toast, scorecard; election banner widget; empty slots `WardServicesSlot`, `WardDrivesSlot` for TASK-12. Neem visuals per §5.4 through TASK-03 tokens only.
15. **Motion (DS §6).**
    1. My Ward rows with `StaggeredColumn` gated by a session flag per ward id.
    2. "Message sent" toast using TASK-03's toast + `MotionCheck` and the success haptic.
    3. Shared `lib/core/widgets/scorecard/{scorecard_stat_tile,scorecard_bar,seen_once}.dart`: `CountUp` numbers and `long` bar growth on first view (visibility-triggered), keyed by `animateKey`; documented for TASK-11 reuse.
    4. Reduced-motion branches reading TASK-03's resolved `reduceMotion` flag; run the no-`Duration(`-literal test.
16. **Staff screens.** `features/staff/representatives/` list + edit + mapping; register nav item (`StaffNavItem`) for TASK-10's shell; minimal `StaffPageScaffold` if the shell is not there. Staff screens use `short` fades only (TASK-10 rule).
17. **Widget tests** W-09-01…W-09-07; emulator checks M-09-03…M-09-09 (motion recordings to `docs/demo/v2-evidence/motion/`); coverage evidence.

## 7. Acceptance Criteria

### 7.1 Behavioral

**AC-1** — My Ward
- **Given** seeded ward 12 with 4 corporators, a ward spanning 2 ACs, 1 MP and ward office details
- **When** a visitor opens My Ward for ward 12
- **Then** 4 corporator rows with Message buttons, both MLAs with the "2 assembly constituencies" note, the MP, the ward office and a scorecard link appear; party shows as plain text with no party colour or logo; loading, empty and offline states match §5.4

**AC-2** — Representative profile
- **Given** one representative with an office landline and one with no phone or email
- **When** each profile opens
- **Then** the first shows the office phone, term, party text, "Source … · Last checked …"; the second shows no phone and a disabled Message button with "We don't have an official email for this representative yet."; the API response has no `user_id` or consent fields

**AC-3** — Relay message sent
- **Given** a signed-in citizen with `share_with_representatives` consent and an issue
- **When** they send a message about the issue without ticking "Share my phone number"
- **Then** 202 `queued`, the outbox sends one email (file driver) to the public address whose body has the issue link and "The resident chose not to share their phone number." and no phone digits; status becomes `sent`; logs contain no subject or body

**AC-4** — Phone shared only on opt-in and consent required
- **Given** a citizen without the relay consent, then with it and `sharePhone=true`
- **When** they send
- **Then** the first attempt returns 403 `CONSENT_REQUIRED` and the app shows the consent sheet; after consent the email includes their +91 number

**AC-5** — Rate limits and idempotency
- **Given** a citizen who has sent 5 messages today to representative R
- **When** they send a 6th to R, resend a previous `clientMessageId`, and send to 20 other representatives
- **Then** the 6th returns 429 with `Retry-After` and the app copy "You've sent 5 messages to this representative today…"; the resend returns 200 with the same id and no second email; the 21st message of the day returns 429

**AC-6** — Profanity screen
- **Given** a message containing a listed English, Gujarati-script or transliterated abusive word
- **When** it is sent
- **Then** 422 `MESSAGE_LANGUAGE`, nothing stored or emailed, the app keeps the text and shows the edit message; a clean message with the word as part of a longer harmless word is accepted

**AC-7** — Roster import rules
- **Given** a CSV with one row missing `source_url`, one with a mobile number `98250 12345`, one with a 5th corporator for ward 12, and 10 valid rows
- **When** `reps:import --dry-run` and then without `--dry-run` runs
- **Then** the dry run lists the 3 errors with row numbers and messages and writes nothing; the commit aborts with nothing written; after fixing the rows a commit creates 10 and a re-run reports all `unchanged`

**AC-8** — Staff CRUD and mapping
- **Given** an admin and a moderator
- **When** the admin edits a representative's party, deactivates another, sets a mobile number, and maps ward 12 to two ACs; the moderator tries an edit
- **Then** the edits and mapping succeed with audit lines; the mobile number returns 400 `REP_PERSONAL_NUMBER`; the deactivated one disappears from My Ward; the moderator gets 403

**AC-9** — Scorecard
- **Given** ward 12 with 12 issues in the last 90 days in mixed statuses, ward 15 with 3, and ward 12 population 50,000
- **When** the refresh job runs and both scorecards open
- **Then** ward 12 shows medians, percentages, backlog and 0.2 reports per 1,000 matching a hand calculation; ward 15 shows "Not enough reports yet" for medians and percentages; the method note opens; hidden/rejected/merged issues are excluded

**AC-10** — Scorecard refresh
- **Given** a new acknowledged issue in ward 12
- **When** `scorecard-refresh` runs (hourly schedule, triggered manually in the test)
- **Then** `refreshed_at` advances, metrics update, and reads during refresh never fail (concurrent refresh)

**AC-11** — Election mode
- **Given** an admin sets election mode for wards 12 and 15 from now for 30 days
- **When** citizens open My Ward, a profile and the scorecard for ward 12 and ward 20, and a representative-authored write for ward 12 hits a route guarded by `assertNotElectionFrozen`
- **Then** ward 12 shows the banner and "The scorecard is paused during the election period." (API `hidden:true`); ward 20 is unaffected; the write returns 409 `ELECTION_MODE_FROZEN`; citizen messages still send; turning it off restores everything within 60 s

**AC-12** — Personal data rules
- **Given** the account-deletion and export routines
- **When** a citizen with relay messages exports and then deletes their account
- **Then** the export lists their messages; after deletion `rep_messages.citizen_id` is NULL and no public endpoint ever exposed the citizen's phone

**AC-13** — My Ward and relay motion
- **Given** animations on, ward 12 with 4 corporators, 2 MLAs and 1 MP, and a signed-in citizen with relay consent
- **When** they open My Ward for the first time, switch to Home and back, open a corporator and send a message
- **Then** on first open the header and rows rise in with a 60 ms stagger (max 6 staggered, later rows with the 6th); returning shows the rows at once with no replay; after sending, the app returns to the profile and a `primaryDark` toast slides up reading "Message sent. We've emailed it to <name>'s office." with its check drawn after the toast lands, a success haptic fires and TalkBack announces the text; every duration comes from `SaartheeMotion`

**AC-14** — Scorecard count-up and bars on first view only
- **Given** animations on and the ward 12 scorecard of AC-9 (verified 75%, 12 issues reported)
- **When** the citizen opens the scorecard, scrolls away and back, pulls to refresh, and then opens it again later in the same session
- **Then** on the first view each number counts up from 0 to its value over `countUp` (integers only) and the two percentage bars grow from 0 to 75% and the reopen value over `long`; scrolling back, refreshing and reopening show final values with no replay; the same `ScorecardStatTile` and `ScorecardBar` widgets are exported from `lib/core/widgets/scorecard/` for TASK-11

**AC-15** — My Ward motion with reduced motion
- **Given** the system "Remove animations" setting on (and separately the in-app Animations switch off)
- **When** the AC-13 and AC-14 steps are repeated
- **Then** rows, toast with its full check, numbers and bars appear at their final state at once or with a ≤ 100 ms cross-fade, and the text, numbers and announcements are identical to the animated run

### AC → Requirement

| AC | Requirements |
|---|---|
| AC-1 | REQ-F-042, REQ-D-008 |
| AC-2 | REQ-F-043, REQ-S-012 |
| AC-3 | REQ-F-044, REQ-S-009 |
| AC-4 | REQ-F-044, REQ-S-009 |
| AC-5 | REQ-S-009, REQ-D-008 |
| AC-6 | REQ-S-009 |
| AC-7 | REQ-F-045, REQ-S-012 |
| AC-8 | REQ-F-045, REQ-S-012 |
| AC-9 | REQ-F-046, REQ-D-012 |
| AC-10 | REQ-D-012 |
| AC-11 | REQ-F-047 |
| AC-12 | REQ-F-044, REQ-D-008 |
| AC-13 | REQ-F-042, REQ-F-044 |
| AC-14 | REQ-F-046 |
| AC-15 | REQ-F-042, REQ-F-044, REQ-F-046 |

### 7.2 Non-Functional Checklist

- [ ] No party colours, symbols or logos anywhere; identical row layout for every representative (neutrality, Spec §11)
- [ ] Every representative shown has `source_url` and `last_verified_at`; profiles older than 180 days flagged in staff list
- [ ] Message subject/body, citizen phone and email addresses never logged; email HTML escapes user text
- [ ] All strings in ARB gu + en, names shown in both scripts; screens work at 2.0× font and 320 dp
- [ ] TalkBack reads "Message <name>, corporator, ward 12"; Call and Message targets ≥ 48 dp
- [ ] `GET /wards/{id}/representatives` p95 < 400 ms; scorecard read is a single indexed row
- [ ] Rate-limit counts survive API restarts (DB-backed)
- [ ] Real roster CSVs contain only public, official information; `SOURCES.md` lists every source
- [ ] Neem visuals only (Baloo Bhai 2 titles/numbers, Mukta Vaani body, radii 14/18/24/pill, Rounded icons, no `sunrise`), all through TASK-03 tokens
- [ ] DS §6 motion uses `SaartheeMotion` tokens only; only transform, opacity and colour animated (bars use `scaleX`); scorecard animates on first view only; reduced motion gives instant equivalents

## 8. Validation & Testing

| Level | ID | What to test | Proves |
|---|---|---|---|
| Static | S-09-01 | API typecheck + lint; `dart format` + `dart analyze` | all |
| API (Vitest) | T-09-01 | Migration CHECKs: area exactly one of ward/AC; landline-only phone without consent; https source | AC-2, AC-7 |
| API (Vitest) | T-09-02 | `GET /wards/{id}/representatives` grouping, multi-AC ward, inactive hidden, no private fields | AC-1, AC-2 |
| API (Vitest) | T-09-03 | Relay happy path with file email driver; body content; no phone; status `sent` | AC-3 |
| API (Vitest) | T-09-04 | Consent missing 403; `sharePhone` includes number | AC-4 |
| API (Vitest) | T-09-05 | Per-rep 5/day, per-user 20/day, IST midnight `Retry-After`, idempotent `clientMessageId` | AC-5 |
| API (Vitest) | T-09-06 | Profanity: en, gu, transliterated hit; substring false-positive avoided | AC-6 |
| API (Vitest) | T-09-07 | Outbox retry: driver fails twice then succeeds; fails 3× → `failed` | AC-3 |
| API (Vitest) | T-09-08 | Importer: dry run errors, atomic abort, idempotent re-run, ward 4-seat cap, mobile refused | AC-7 |
| API (Vitest) | T-09-09 | Staff CRUD + mapping + role checks (admin 200, moderator 403, citizen 403) | AC-8 |
| API (Vitest) | T-09-10 | Scorecard view numbers vs fixture hand calculation; min sample nulls; exclusions | AC-9 |
| API (Vitest) | T-09-11 | Concurrent refresh while reading | AC-10 |
| API (Vitest) | T-09-12 | Election mode: city vs wards scope, window, scorecard hidden, 409 `ELECTION_MODE_FROZEN` on guarded test route, cache invalidation | AC-11 |
| API (Vitest) | T-09-13 | Export includes messages; deletion nulls `citizen_id` | AC-12 |
| API (Vitest) | T-09-14 | Log redaction: subject/body/phone absent from captured logs | AC-3 |
| Widget | W-09-01 | Representative row: initials, both scripts, party text, Message button semantics | AC-1 |
| Widget | W-09-02 | My Ward states: no ward, partial seats, empty, error, offline | AC-1 |
| Widget | W-09-03 | Message form: counter, opt-in unchecked by default, error copy per code | AC-4, AC-5, AC-6 |
| Widget | W-09-04 | Scorecard tiles: small sample, missing population, election paused | AC-9, AC-11 |
| Widget | W-09-05 | Election banner text and semantics | AC-11 |
| Widget | W-09-06 | My Ward stagger: pump `SaartheeMotion.stagger` steps and assert row opacity/offset order, rows 7+ appear with row 6; re-entering pumps one frame and all rows are final; "Message sent" toast: after `SaartheeMotion.springIn` the toast is at rest, `MotionCheck` progress is 0 before the 150 ms delay and 1 after `drawCheck`; haptics fake records one success; reduced-motion variant: one `pump()` shows rows and full check | AC-13, AC-15 |
| Widget | W-09-07 | `ScorecardStatTile`/`ScorecardBar`: mid-`countUp` the number is an integer between 0 and the target and equals it after `SaartheeMotion.countUp`; bar `scaleX` is 0 at start and the target after `SaartheeMotion.long`; rebuilding with the same `animateKey` (or new data) shows the final state in one frame; reduced-motion variant shows final values after one `pump()` | AC-14, AC-15 |
| Manual | M-09-01 | `reps:import --dry-run` on the compiled pilot roster; review report; commit on staging | AC-7 |
| Manual | M-09-02 | SES sandbox send to a team inbox; check SPF/DKIM pass and rendering in Gmail | AC-3 |
| Manual | M-09-03 | Emulator: My Ward → corporator → Message (sign-in, consent) → "Message sent" toast | AC-1, AC-3, AC-4 |
| Manual | M-09-04 | Emulator: sixth message refused; abusive word refused with text kept | AC-5, AC-6 |
| Manual | M-09-05 | Emulator: election mode on for ward → banner and paused scorecard; off → restored | AC-11 |
| Manual | M-09-06 | TalkBack + 2.0× font on My Ward, profile, message, scorecard in Gujarati | AC-1, AC-2 |
| Manual | M-09-07 | Spot-check 10 roster rows against their source URLs (second person) | AC-7 |
| Manual | M-09-08 | Emulator recordings (`adb shell screenrecord /sdcard/<name>.mp4`, `adb pull` to `docs/demo/v2-evidence/motion/`): `t09-my-ward-stagger.mp4` (first load, tab return), `t09-message-sent-toast.mp4`, `t09-scorecard-countup.mp4` (first view, scroll back, refresh) | AC-13, AC-14 |
| Manual | M-09-09 | Repeat M-09-08 with "Remove animations" on and with the in-app switch off; `t09-reduced-motion.mp4` | AC-15 |

## 9. Deliverables

- Migrations `<ts>_v2_representatives`, `<ts>_v2_ward_scorecard` (and `<ts>_v2_app_settings` if first); Prisma models; seed additions.
- Scripts `reps:import`, `constituencies:import`; compiled roster + mapping CSVs and `SOURCES.md`.
- API modules `representatives`, `settings` (public + election mode), `staff-representatives`; libs `mail`, `profanity`; jobs `relay-send`, `scorecard-refresh`; `assertNotElectionFrozen`.
- App: `features/ward` (My Ward, profile, message + "Message sent" toast, scorecard, election banner), `features/staff/representatives`; shared `lib/core/widgets/scorecard/` (`ScorecardStatTile`, `ScorecardBar`, `SeenOnce`) reused by TASK-11.
- Tests T-09-01…14, W-09-01…07; manual evidence M-09-01…09 (motion recordings in `docs/demo/v2-evidence/motion/`); coverage evidence for 10 requirements.

## 10. Files Expected to Change

Prediction only — exact paths may differ.

| Path | Change |
|---|---|
| `apps/api/prisma/migrations/<ts>_v2_{representatives,ward_scorecard,app_settings}/`, `prisma/schema.prisma` | New / Modified |
| `apps/api/prisma/seed*` | Modified |
| `apps/api/scripts/{import-representatives,import-constituencies}.ts`, `apps/api/package.json` | New / Modified |
| `apps/api/data/representatives/{roster-2026.csv,constituencies.csv,SOURCES.md}` | New |
| `apps/api/src/modules/{representatives,settings,staff-representatives}/` | New |
| `apps/api/src/lib/{mail,profanity}/`, `src/middleware/electionFreeze.ts`, `src/jobs/{relay-send,scorecard-refresh}.ts` | New |
| `apps/api/src/modules/me/privacy.registry.ts` registrations (TASK-04 registry) | Modified |
| `apps/api/src/lib/{errors,audit,logger}/`, `src/routes.ts`, `src/config/` | Modified |
| `apps/api/test/{representatives,relay,import,scorecard,election}*.test.ts`, `test/fixtures/roster/` | New |
| `apps/mobile/lib/features/ward/`, `lib/features/staff/representatives/` | New |
| `apps/mobile/lib/core/widgets/scorecard/{scorecard_stat_tile,scorecard_bar,seen_once}.dart` | New |
| `docs/demo/v2-evidence/motion/t09-*.mp4` | New |
| `apps/mobile/lib/router/{citizen_routes,staff_routes}.dart`, `lib/core/l10n/app_*.arb` | Modified |
| `apps/mobile/test/ward/` | New |

## 11. Related Documentation

- `docs/v2/saarthee-v2-spec.md` §2 (D2, D5), §3, §6, §7, §8, §11
- `docs/v2/design-system.md` DS §2–§4 (Neem tokens, type, shape, icons), §5 (Representative row, Stat tiles, Toast, Banners), §6 (Motion: My Ward, Scorecard and dashboards, rules), §7 (accessibility), §8 (Find my corporators), §9
- `docs/tasks-v2/TASK-03-design-system-shell.md` — `SaartheeMotion`, `StaggeredColumn`, `MotionCheck`, `CountUp`, toast
- `docs/tasks-v2/TASK-10-staff-console.md` — `app_settings` DDL, staff `requireRole` contract, settings UI shell
- `docs/tasks-v2/TASK-11-*.md` — claims, rep inbox, use of `assertNotElectionFrozen`
- State Election Commission Gujarat results; ECI results 2022/2024; MyNeta (ADR) affidavits; Delimitation Order 2008

## 12. Risks & Considerations

| Risk | Impact | Mitigation |
|---|---|---|
| Hand-compiled roster has errors | Wrong person shown or messaged | Primary source URL per row, second-person spot check, "Last checked" date, staff correction flow |
| A personal number slips into the data | Privacy harm, legal exposure | Importer and API refuse all mobiles; DB CHECK; only consented numbers via TASK-11 |
| Representatives see relay as spam | Emails blocked, low reply rate | Rate limits, profanity screen, clear sender identity, opt-out contact, SPF/DKIM/DMARC |
| SES sandbox/production access delay | Relay cannot send in staging | File driver for dev; request access early; provider swappable behind `src/lib/mail` |
| Scorecard misread as an official AMC rating | Political and trust risk | Method note, "Based only on reports made in Saarthee", sample threshold, hidden in election mode |
| Election-mode rules unclear under the Model Code of Conduct | Compliance risk | Conservative hiding; legal review (Open Question 6) before pilot |
| Ward ↔ AC mapping errors after 2026 delimitation | Wrong MLA shown | Source per mapping row; cross-check with TASK-02's boundary verification |
| Scorecard animation replays on every rebuild or refresh | Distracting; numbers hard to read | `SeenOnce` registry keyed per ward; W-09-07 asserts no replay |
| Shared scorecard widgets diverge from TASK-11's needs | Duplicate widgets | Keep API small (`value`, `label`, `animateKey`, optional bar); TASK-11 extends rather than copies |

## 13. Progress Status

**Current status:** Not Started

**Progress:** 0%

| Date | Progress | Commit |
|---|---|---|

## 14. Completion Checklist

- [ ] All implementation steps complete
- [ ] All behavioral acceptance criteria verified in the running application
- [ ] Non-functional checklist fully ticked
- [ ] Static checks pass and every AC verified by the tests and manual checks in §8
- [ ] Automated tests added and passing
- [ ] Frontend and backend integrated end to end (no mocked data left in place)
- [ ] Error, loading, empty, and unauthorized states verified
- [ ] Code reviewed against the patterns established in earlier tasks
- [ ] Assumptions documented and, where possible, confirmed
- [ ] Coverage matrix rows for this task's requirements set to Pass with evidence (`check_coverage.py --task TASK-09` shows 0 unverified)
- [ ] Task file progress log and status updated
- [ ] `00-task-summary.md` updated
- [ ] Committed as `V2-TASK-09: …`
- [ ] Validator passes
- [ ] My Ward, profile, message and scorecard match Neem v2.2 (tokens, type, radii, Rounded icons)
- [ ] DS §6 motion (row stagger, "Message sent" toast with drawn check, scorecard `CountUp` + bars on first view) implemented with `SaartheeMotion` tokens; W-09-06 and W-09-07 pass
- [ ] Shared scorecard widgets exported in `lib/core/widgets/scorecard/` for TASK-11
- [ ] Reduced-motion variants verified; motion recordings saved to `docs/demo/v2-evidence/motion/` (M-09-08, M-09-09)
