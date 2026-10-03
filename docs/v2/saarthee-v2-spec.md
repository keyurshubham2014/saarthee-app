# Saarthee v2 — Product & Technical Specification

**Version:** 2.0 draft · **Date:** 2026-10-03 · **Owner:** founder (decisions D1–D12 taken by the build lead on the founder's instruction; each can be overruled)
**Inputs:** `docs/research/saarthee-v2-proposal.html` (four research tracks), v1 code audit, v1 spec set `docs/00…07`.
**Supersedes:** v1 scope where they conflict. v1 stays the base: its API foundation, photo pipeline, draft safety, admin auth, audit/redaction rules and static-check gates are kept.

---

## §1 Vision and scope

Saarthee becomes the single civic app for Amdavadis: report any civic issue directly, follow it to a fix that neighbours verify, reach the four corporators of your ward, get water-cut / road-closure / heat alerts for your ward, find AMC services, and join civic drives. Filing with AMC's CCRS becomes an optional hand-off.

Saarthee is **independent**. It never uses the AMC logo or claims to file complaints on AMC's behalf. Every screen that shows AMC information names its source.

**Out of scope for v2:** payments, an AMC system integration (no public API exists), WhatsApp/SMS channels (phase 3), Hindi (phase 3), iOS store release (Android first; iOS kept buildable), ward polls, open-data portal.

## §2 Decisions

| # | Decision | Rationale |
|---|---|---|
| D1 | "Neem" visual identity (§10, `docs/v2/design-system.md` v2.2): neem green brand, sunrise orange for Report only, Baloo Bhai 2 headings with Mukta Vaani text, rounded cards, gentle spring motion. Chosen by the founder 2026-10-03 from four directions (`docs/v2/design-options.html`); no AMC logo or AMC-derived marks | Community feel and trust without impersonation |
| D2 | Corporator contact: in-app message relay (email to representative) by default; phone shown only if officially published as an office number or consented | Never publish personal numbers |
| D3 | Roles: citizen, moderator, admin, representative (verified). Alerts at Warning/Critical need two-person approval | A wrong alert damages trust |
| D4 | Languages: Gujarati + English at launch; Hindi phase 3 | Audience; scope |
| D5 | Built for all 48 wards; launch outreach in 5 West-zone wards (Paldi, Navrangpura, Vasna, Naranpura, Nava Vadaj) | Same code, focused launch |
| D6 | Browse without account; phone OTP sign-in required to report, Me too, follow, verify, message, RSVP | Identity for social features and abuse control |
| D7 | Admin, moderator and representative consoles are the same Flutter codebase, built for web and also reachable in-app | One front-end stack |
| D8 | Phone OTP via Firebase Authentication; API verifies the Firebase ID token and issues its own session JWT | No SMS DLT setup needed for OTP; free tier sufficient for pilot |
| D9 | Push via Firebase Cloud Messaging topics (`ward_<n>`, `zone_<code>`, `cat_<slug>`, `city_all`) + in-app inbox | Free; WhatsApp/SMS later |
| D10 | PostGIS for wards (switch image to `postgis/postgis:17-3.5`); wards seeded from OpenCity "AMC Wards Map 2024" (public domain), cross-checked with AMC's ward list | Ward detection from GPS |
| D11 | v1 pilot constructs (invite codes, source tags, H1/H2 rates, manual WhatsApp verify tokens) are retired from the citizen UI; tables kept read-only for history | Simplify; no data loss |
| D12 | Deployment for the pilot: one Linux VM (or managed container) for the API behind HTTPS, managed PostgreSQL with PostGIS, Cloudflare R2 for photos, daily backups | v1 deferred deployment (REQ-O-022); a pilot needs it |

## §3 Users and roles

| Role | How obtained | Can |
|---|---|---|
| Visitor | Opens app | Browse feed, map, issues, alerts, services, ward directory |
| Citizen | Phone OTP | Report, Me too, follow, verify/reopen own and nearby issues, comment (structured), message representative, RSVP, manage alerts, export/delete own data |
| Moderator | Admin grants | Moderation queue, edit category/ward of issues, draft alerts, approve Info/Advisory alerts, first approval of Warning/Critical |
| Admin | `admin:create` | Everything; second approval of Warning/Critical; manage reps, categories, services, initiatives, election mode |
| Representative | Claim flow, admin-verified | Ward dashboard, acknowledge + comment on ward issues, export; (P2) ward updates |

## §4 Issue taxonomy

14 Saarthee categories, each mapped to one or more AMC CCRS department/problem types (from `amccrs.com/AMCPortal/Home/GetDeptWiseProblems`, cached in `amc_problem_types`, not hammered):

`roads` Roads & potholes (Engineering) · `water` Water supply (Engineering, Health) · `drainage` Drainage & waterlogging (Engineering) · `garbage` Garbage & cleanliness (SWM) · `streetlight` Streetlights (Light) · `trees` Trees & parks (Garden) · `animals` Stray animals (CNCD) · `health` Mosquitoes & health (Health) · `toilets` Public toilets (SWM) · `encroachment` Encroachment (Estate) · `traffic` Traffic & parking (Estate / Traffic Police) · `property` Property & tax (Property Tax) · `building` Building & construction (Town Planning, Fire) · `other` Other (moderator routes).

Each category has: slug, name_en, name_gu, icon, colour token, default SLA days (configurable; shown as "Saarthee target", never as an AMC SLA unless AMC publishes one), active flag, sort order, sensitive flag (structured form only).

## §5 Issue lifecycle

States: `reported` → `sent` (citizen filed with CCRS or escalated; channel logged) → `acknowledged` (by representative/moderator or citizen-entered CCRS acknowledgement) → `in_progress` → `marked_fixed` → `verified` | `reopened`. Plus `rejected` (moderator: spam/duplicate/out of area, with reason) and `merged` (duplicate merged into a canonical issue).

Rules:
- Status history is an append-only `issue_events` table (who, role, from, to, note, photo, time). Current status is derived/stored on the issue for querying.
- **Marked fixed** can be set by reporter, a representative or moderator, optionally with an "after" photo.
- **Verified** requires a citizen (reporter or any signed-in citizen) to submit a photo taken within **100 m** of the issue location (configurable `VERIFY_RADIUS_M`) answering "Fixed". Two "Not fixed" answers or the reporter's "Not fixed" → `reopened`.
- Reopen window: 7 days after `marked_fixed` (configurable). After 7 days with no answer the issue shows "Fixed (not verified)".
- If the citizen linked a CCRS number, the app reminds them on the day CCRS closes it (citizen marks "AMC closed it") that CCRS reopening is only possible within 24 h.
- SLA timer per category from `reported`; overdue issues are flagged and enter the escalation ladder.
- **Escalation ladder** (citizen-triggered, P0 as pre-filled message, P1 auto-suggested when overdue): ward corporators (relay) → zone office (email/phone from AMC ward list) → Deputy Municipal Commissioner of zone → Municipal Commissioner. Saarthee generates the message with evidence link; it never claims to be an official filing.
- **Duplicates:** before submit, find open issues of the same category within 50 m (configurable) in the last 30 days; offer "Me too" on the existing one. Moderators can merge.

## §6 Data model (new and changed, PostgreSQL + PostGIS)

New migrations only; applied v1 migrations are never edited.

| Table | Key columns |
|---|---|
| `zones` | id, code, name_en, name_gu, geom MultiPolygon NULL |
| `wards` | id, number, name_en, name_gu, zone_id, geom MultiPolygon(4326) GIST, boundary_version, office_address, office_phone (public), population NULL |
| `users` | id, phone_e164 UNIQUE, firebase_uid UNIQUE, display_name NULL, home_ward_id NULL, language (gu/en), role (citizen/moderator/admin/representative), status (active/suspended/deleted), created_at, last_seen_at |
| `consents` | id, user_id, purpose (core_service / share_with_representatives / share_with_amc_handoff / notifications), text_version, granted_at, withdrawn_at |
| `devices` | id, user_id NULL, install_id, fcm_token, platform, app_version, last_seen_at |
| `categories` | id, slug UNIQUE, name_en, name_gu, icon, colour_token, sla_days, sensitive, is_active, sort_order |
| `amc_problem_types` | id, dept_en, dept_gu, problem_en, problem_gu, category_id, fetched_at |
| `issues` | id, client_submission_id UNIQUE, reporter_id → users, category_id, title (auto from category + place, editable), description ≤ 1,000, location geography(Point) + lat/lng, gps_accuracy_m, ward_id, zone_id, address_text NULL (reverse-geocode later), status, status_changed_at, sla_due_at, me_too_count, follower_count, ccrs_number NULL, ccrs_filed_at NULL, visibility (public/hidden), is_sensitive, created_at, updated_at, legacy_complaint_id NULL |
| `issue_photos` | issue_id, photo_id, kind (report/after/verification), position |
| `issue_events` | id, issue_id, actor_id, actor_role, type (status_change/comment/ccrs_linked/escalated/merged/rejected), from_status, to_status, note ≤ 500, photo_id NULL, created_at |
| `issue_verifications` | id, issue_id, user_id, answer (fixed/not_fixed), photo_id, lat/lng, distance_m, created_at — UNIQUE(issue_id, user_id, day) |
| `me_toos` | issue_id, user_id, created_at — PK(issue_id, user_id) |
| `follows` | issue_id, user_id, created_at — PK |
| `representatives` | id, name_en, name_gu, role (corporator/mla/mp), party_text, term_start, term_end, public_phone NULL, public_email NULL, contact_consent_at NULL, photo_url NULL, source_url, last_verified_at, user_id NULL, verified_at, verified_method |
| `representative_areas` | representative_id, ward_id NULL, assembly_constituency_id NULL |
| `assembly_constituencies` / `ward_constituency` | MLA/MP lookup (many-to-many with wards) |
| `rep_claims` | id, representative_id, user_id, evidence_photo_ids, otp_verified, status, reviewer_id, decided_at, note |
| `rep_messages` | id, representative_id, citizen_id, issue_id NULL, subject, body ≤ 1,000, status (queued/sent/failed/replied), sent_at |
| `alerts` | id, type (water_cut/water_timing/road_closure/heat/rain_flood/health/initiative/other), severity (info/advisory/warning/critical), title_en/gu, body_en/gu, source_name, source_url, valid_from, valid_to, area geom NULL, status (draft/pending_approval/published/expired/retracted), created_by, approved_by[], supersedes_id, origin (manual/imd/sachet), published_at |
| `alert_wards` | alert_id, ward_id |
| `subscriptions` | user_id or device_id, scope (ward/zone/city), scope_id, category NULL, channel (push), created_at |
| `notifications` | id, user_id/device_id NULL, topic NULL, kind (alert/issue_update/initiative/system), ref_id, title, body, sent_at, status, read_at |
| `services` | id, slug, name_en/gu, department, summary_en/gu, url, online (bool), how_to_en/gu (markdown), last_checked_at, link_ok |
| `initiatives` | id, title_en/gu, type (tree_drive/cleanup/health_camp/other), organiser (AMC/RWA/NGO/Saarthee), source_url, ward_id NULL, location, starts_at, ends_at, capacity NULL, status |
| `rsvps` | initiative_id, user_id, status (going/cancelled/attended), created_at |
| `moderation_flags` | id, target_type, target_id, reporter_id, reason, status, handled_by, handled_at |
| `app_settings` | election_mode (per city/ward, from/to), feature flags |

Legacy: `complaints` rows are migrated into `issues` (`legacy_complaint_id` set; CCRS number kept; status mapped: filed→reported, reminded→sent, verified_fixed→verified, verified_not_fixed→reopened). v1 tables become read-only.

## §7 API (base `/api/v1`, v1 conventions kept)

Auth: citizen session JWT (`Authorization: Bearer`) from `POST /auth/firebase` exchanging a Firebase ID token; staff (admin/moderator/representative) use the same user model with roles. v1 admin email/password login stays for admins until all staff move to OTP.

| Area | Endpoints |
|---|---|
| Auth & me | `POST /auth/firebase` · `POST /auth/logout` · `GET/PATCH /me` (name, language, home ward) · `GET /me/export` · `DELETE /me` · `POST /me/consents` · `POST /devices` (FCM token) |
| Geo | `GET /wards` · `GET /wards/{id}` · `GET /geo/locate?lat&lng` → ward, zone · `GET /zones` |
| Categories | `GET /categories` (v2 list with AMC mapping) |
| Issues | `POST /photos` (kept) · `POST /issues` (idempotent) · `GET /issues/nearby?lat&lng&category` (dup check) · `GET /issues` (filters: ward, category, status, bbox, sort, cursor) · `GET /issues/{id}` · `POST /issues/{id}/me-too` · `DELETE …/me-too` · `POST/DELETE /issues/{id}/follow` · `POST /issues/{id}/ccrs` (link number) · `POST /issues/{id}/status` (role-checked transitions) · `POST /issues/{id}/verifications` · `POST /issues/{id}/escalations` (returns message) · `POST /issues/{id}/flags` · `GET /issues/{id}/events` |
| Feed & map | `GET /feed?ward` (issues, alerts, initiatives, service tips) · `GET /map/issues?bbox&zoom` (clusters server-side above zoom threshold) |
| Representatives | `GET /wards/{id}/representatives` · `GET /representatives/{id}` · `POST /representatives/{id}/messages` (relay) · `POST /representatives/{id}/claims` |
| Alerts | `GET /alerts?ward&active` · `GET /alerts/{id}` · `GET/PUT /me/subscriptions` · `GET /me/notifications` · `POST /me/notifications/read` |
| Services & initiatives | `GET /services` · `GET /services/{slug}` · `GET /initiatives?ward&upcoming` · `POST/DELETE /initiatives/{id}/rsvp` |
| Staff (role-guarded) | `GET /staff/moderation` · `POST /staff/issues/{id}/{reject|merge|recategorise|hide}` · `POST/PATCH /staff/alerts` · `POST /staff/alerts/{id}/approve|publish|retract` · CRUD `/staff/representatives`, `/staff/services`, `/staff/initiatives`, `/staff/categories` · `GET/POST /staff/rep-claims/{id}/decide` · `GET /staff/ward-dashboard?ward` (representative scope) · `GET /staff/export` · `PUT /staff/settings/election-mode` |
| Public stats | `GET /wards/{id}/scorecard` (median days to acknowledge/fix, verified %, reopen %, open backlog, reports per 1,000 residents) |

Rate limits (per user unless noted): issues 10/day, me-too 100/day, messages 5/day per representative, verifications 20/day, OTP via Firebase limits, public reads 120/IP/min.

## §8 Screens and navigation (mobile + web console)

Citizen bottom navigation: **Home · Map · Report · Alerts · My Ward**. Profile, settings and services are reached from My Ward and Home.

| Route | Screen |
|---|---|
| `/onboarding/language`, `/onboarding/intro`, `/onboarding/ward` | Language first (ગુજરાતી / English), one intro screen with independence notice, set home ward (GPS or picker) |
| `/sign-in`, `/sign-in/otp` | Phone + OTP (shown only when an action needs it) |
| `/` Home | Ward header, active alerts strip, "Report an issue" primary action, nearby issues, upcoming drives, service shortcuts |
| `/map` | Issues map with clusters and filters (category, status, mine) |
| `/report/what`, `/report/photo`, `/report/details`, `/report/done` | Three short steps (DS §8): 1 category grid; 2 photos + auto location with adjustable pin + duplicate suggestions; 3 optional description (voice), summary with Change links → Submit; offline draft kept |
| `/issues/:id` | Photos (before/after), status + timeline, Me too, Follow, Share, Verify/Reopen, Link CCRS, Escalate, report a problem |
| `/alerts`, `/alerts/:id`, `/alerts/settings` | Inbox of active and past alerts; subscription settings |
| `/ward`, `/ward/:id`, `/representatives/:id`, `/representatives/:id/message` | My Ward: corporators, MLA/MP, ward office, scorecard, services, drives |
| `/services`, `/services/:slug` | AMC services directory |
| `/initiatives`, `/initiatives/:id` | Drives with RSVP |
| `/me`, `/me/reports`, `/me/following`, `/me/settings`, `/me/privacy` | Profile, my issues, following, language, notifications, data export/delete, about & independence |
| `/staff/*` (web + app) | Moderation queue, issue tools, alerts composer + approvals, representatives, claims, services, initiatives, categories, election mode, ward dashboard (representatives), exports |

## §9 Notifications

- FCM topics: `ward_<number>`, `zone_<code>`, `cat_<slug>`, `city_all`; per-user tokens for issue updates of followed/own issues.
- Kinds: alert (by ward/zone/city + severity), issue update (status change, verification request, reopen), initiative reminder (24 h before), system.
- Quiet hours 22:00–07:00 except Critical. In-app inbox stores every notification for 90 days.
- Alert ingestion (P1): IMD district warnings (if access granted) and NDMA SACHET CAP RSS create **drafts** only.
- Every alert shows "Source: <name> (link) · Relayed by Saarthee" and its validity window; auto-expires.

## §10 Design system

See `docs/v2/design-system.md` v2.2 "Neem" (DS §1–§9: identity, colour, type, shape, components, motion, accessibility, flows, screens). Summary: neem-green brand with a green Home header, a single sunrise-orange Report action, Baloo Bhai 2 headings and Mukta Vaani text (Gujarati + English), rounded cards with soft depth and generous spacing, semantic colours for status and severity, icon + label everywhere, 48 dp minimum targets, and a gentle-spring motion system (DS §6) that respects reduced motion and holds 60 fps on low-end phones.

## §11 Privacy, safety and trust

- DPDP Act 2023 / Rules 2025 (full duties from 13 May 2027; build now): purpose-specific consent records (§6 `consents`), notice in Gujarati and English, access/export, erasure (anonymise issues, delete photos of the person, keep aggregate), grievance contact in app, retention (photos 2 years after closure; logs 14 days), breach procedure documented, users under 18 blocked at sign-in (age confirmation).
- Public pages never show reporter phone or name (display "A resident of <ward>"); representative relay hides citizen phone unless the citizen opts to share.
- Photos: EXIF stripped (v1), faces and number plates blurred on-device before upload (ML Kit face detection + plate heuristic; manual blur tool fallback); moderation can hide.
- No posts about private individuals; sensitive categories use structured fields only; Kindness prompt before comments.
- Abuse: rate limits (§7), flagging, moderator queue, suspension, audit log of every staff action.
- Neutrality: identical treatment of all representatives, no party colours/logos, election mode freezes representative-authored content and hides comparative stats.
- Independence labelling on About, alerts, services and every AMC hand-off.

## §12 Operations

- Environments: local (Docker PostGIS), staging, pilot production. HTTPS only outside local; cleartext exceptions removed from profile/release builds.
- Storage: Cloudflare R2 driver implemented behind the v1 storage interface.
- Backups: daily `pg_dump` + R2 versioning; restore drill before launch.
- Monitoring: uptime check on `/health`, error logging (no PII), weekly `npm audit`.
- Release: Android internal testing → closed testing (pilot wards) → production; release signing keys; Play Data safety form consistent with §11.
- Verification posture: v1's "no automated tests" decision is **reversed for v2**: API integration tests (Vitest + Supertest) for lifecycle, permissions and rate limits, and Flutter widget/integration tests for report and verify, because v2 has many more roles and transitions.
