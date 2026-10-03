# Coverage Verification Matrix — Saarthee v2

**Last Updated:** 2026-10-03
**Verified:** 0 / 112 (0%)
**Owner of final sign-off:** TASK-14 (REQ-O-009)

One row per active requirement in [requirements-registry.md](./requirements-registry.md). Rows are generated with
`python3 docs/tasks-v2/check_coverage.py --sync`. Set a task's rows to `Pass` (or `Fail`) with evidence when it closes;
TASK-14 closes the matrix. Evidence: a test name, a check ID from the task's §8, a screenshot file, a curl command, an SQL query or a commit hash.

Statuses: `Not Verified` · `Pass` · `Fixed` · `Fail` · `Deferred` (Evidence names who decided and when).

## Matrix

| Req ID | Requirement | Owner | Status | Evidence | Verified On |
|---|---|---|---|---|---|
| REQ-F-001 | `GET /geo/locate?lat&lng` returns ward and zone via PostGIS point-in-polygon; nearest ward with `confirm:tr... | TASK-02 | Not Verified | — | — |
| REQ-F-002 | `GET /wards`, `GET /wards/{id}`, `GET /zones` with Gujarati and English names, zone, ward office address an... | TASK-02 | Not Verified | — | — |
| REQ-F-003 | Ward picker data: searchable list of 48 wards grouped by 7 zones | TASK-02 | Not Verified | — | — |
| REQ-F-004 | Onboarding: language first (ગુજરાતી / English), one intro screen with independence notice, set home ward by... | TASK-03 | Not Verified | — | — |
| REQ-F-005 | Citizen app shell with five tabs (Home, Map, Report, Alerts, My Ward), state kept per tab | TASK-03 | Not Verified | — | — |
| REQ-F-006 | Language switch in settings changes the whole app instantly; preference stored on device and on the account | TASK-03 | Not Verified | — | — |
| REQ-F-007 | Phone OTP sign-in (Firebase Authentication) shown only when an action needs an account; returns to the acti... | TASK-04 | Not Verified | — | — |
| REQ-F-008 | `POST /auth/firebase` exchanges a verified Firebase ID token for a Saarthee session JWT; `POST /auth/logout` | TASK-04 | Not Verified | — | — |
| REQ-F-009 | `GET/PATCH /me` (display name, language, home ward); profile screen | TASK-04 | Not Verified | — | — |
| REQ-F-010 | `POST /devices` registers the FCM token per install and user; topic subscription for home ward and `city_all` | TASK-04 | Not Verified | — | — |
| REQ-F-011 | Server push service (FCM HTTP v1) for topics and individual tokens, with a delivery log in `notifications` | TASK-04 | Not Verified | — | — |
| REQ-F-012 | v2 category list (14 categories, Gujarati + English, icon, colour token, SLA days) via `GET /categories`, w... | TASK-05 | Not Verified | — | — |
| REQ-F-013 | AMC problem types cached from the CCRS public JSON by a script (manual run, at most daily) | TASK-05 | Not Verified | — | — |
| REQ-F-014 | Three-step report flow (DS §7): category grid; photos (1–3) with auto location and adjustable pin; optional... | TASK-05 | Not Verified | — | — |
| REQ-F-015 | Duplicate check before submit: open issues of the same category within 50 m in 30 days offered as "Me too" | TASK-05 | Not Verified | — | — |
| REQ-F-016 | `POST /issues` idempotent by `clientSubmissionId`; assigns ward/zone, SLA due date, status `reported` | TASK-05 | Not Verified | — | — |
| REQ-F-017 | Report draft persists across app kill and camera hand-off; image_picker lost-data recovery handled | TASK-05 | Not Verified | — | — |
| REQ-F-018 | Optional "File with AMC too" hand-off (CCRS web, WhatsApp, 155303) showing the matching AMC problem type; c... | TASK-05 | Not Verified | — | — |
| REQ-F-019 | Voice input for the description (device speech-to-text, gu/en) | TASK-05 | Not Verified | — | — |
| REQ-F-020 | Issue status transitions enforced server-side by role (§5 state machine); every change appended to `issue_e... | TASK-06 | Not Verified | — | — |
| REQ-F-021 | Marked-fixed by reporter, representative or moderator, optionally with an after photo | TASK-06 | Not Verified | — | — |
| REQ-F-022 | Verification: citizen answers Fixed/Not fixed with a photo within `VERIFY_RADIUS_M` (100 m); rules move the... | TASK-06 | Not Verified | — | — |
| REQ-F-023 | Reopen window of 7 days after marked-fixed; after that the issue shows "Fixed (not verified)" | TASK-06 | Not Verified | — | — |
| REQ-F-024 | SLA due date per category; overdue issues flagged in lists and detail | TASK-06 | Not Verified | — | — |
| REQ-F-025 | Escalation ladder: pre-filled message to corporators (relay), zone office, deputy commissioner, commissione... | TASK-06 | Not Verified | — | — |
| REQ-F-026 | CCRS 24-hour reopen reminder when the citizen marks "AMC closed it" | TASK-06 | Not Verified | — | — |
| REQ-F-027 | Followers and reporter get push + inbox notifications on status changes and verification requests | TASK-06 | Not Verified | — | — |
| REQ-F-028 | Home feed for the selected ward: alerts strip, report action, nearby issues, upcoming drives, service short... | TASK-07 | Not Verified | — | — |
| REQ-F-029 | Map tab with clustered issue pins, category/status/"mine" filters, bottom-sheet preview (`GET /map/issues`) | TASK-07 | Not Verified | — | — |
| REQ-F-030 | Issue detail: photos with before/after, status and timeline, Me too, Follow, Share, Verify/Reopen, Link CCR... | TASK-07 | Not Verified | — | — |
| REQ-F-031 | Me too and Follow (`POST/DELETE`) with counts; one per user | TASK-07 | Not Verified | — | — |
| REQ-F-032 | Share an issue as an image card plus link to WhatsApp and other apps | TASK-07 | Not Verified | — | — |
| REQ-F-033 | My reports and Following lists with status chips | TASK-07 | Not Verified | — | — |
| REQ-F-034 | Issue list API with filters (ward, category, status, bbox), sort (newest, most affected, overdue) and curso... | TASK-07 | Not Verified | — | — |
| REQ-F-035 | Staff alert composer: type, severity, bilingual title/body, source name + URL, validity window, wards or zo... | TASK-08 | Not Verified | — | — |
| REQ-F-036 | Alert approval: Info/Advisory by one moderator; Warning/Critical need two different approvers; publish, ret... | TASK-08 | Not Verified | — | — |
| REQ-F-037 | Published alerts pushed to ward/zone/city topics respecting quiet hours (except Critical); auto-expire at `... | TASK-08 | Not Verified | — | — |
| REQ-F-038 | Alerts tab: active and past alerts for my wards, severity banner, source line, validity; alert detail | TASK-08 | Not Verified | — | — |
| REQ-F-039 | Alert subscription settings: extra wards, categories of alerts, mute non-critical | TASK-08 | Not Verified | — | — |
| REQ-F-040 | Notification inbox (90 days) with read state, across alerts, issue updates and initiatives | TASK-08 | Not Verified | — | — |
| REQ-F-041 | Draft alerts created automatically from NDMA SACHET CAP RSS (and IMD district warnings if access is granted... | TASK-08 | Not Verified | — | — |
| REQ-F-042 | My Ward screen: four corporators, MLA, MP, ward office, scorecard link, services and drives for the ward | TASK-09 | Not Verified | — | — |
| REQ-F-043 | Representative profile: name (gu/en), role, party as plain text, term, office contact if published, source ... | TASK-09 | Not Verified | — | — |
| REQ-F-044 | Message relay: citizen sends a message (optionally about an issue) that Saarthee emails to the representati... | TASK-09 | Not Verified | — | — |
| REQ-F-045 | Representative roster import tool (CSV with source URLs) and staff CRUD for representatives and ward–consti... | TASK-09 | Not Verified | — | — |
| REQ-F-046 | Public ward scorecard: median days to acknowledge and to fix, verified %, reopen %, open backlog, reports p... | TASK-09 | Not Verified | — | — |
| REQ-F-047 | Election mode per city or ward: freezes representative-authored content and hides comparative stats, with a... | TASK-09 | Not Verified | — | — |
| REQ-F-048 | Staff console runs as a Flutter web build and in-app under `/staff`, role-aware navigation | TASK-10 | Not Verified | — | — |
| REQ-F-049 | Moderation queue: new issues in sensitive categories, flagged content, out-of-area issues; actions reject (... | TASK-10 | Not Verified | — | — |
| REQ-F-050 | Staff management of roles (grant/revoke moderator), categories, and app settings | TASK-10 | Not Verified | — | — |
| REQ-F-051 | Content flagging by citizens on issues and comments | TASK-10 | Not Verified | — | — |
| REQ-F-052 | Staff exports (CSV) of issues, events and verifications without phone numbers by default | TASK-10 | Not Verified | — | — |
| REQ-F-053 | Representative claim flow: OTP-verified phone plus evidence upload, reviewed and approved by an admin | TASK-11 | Not Verified | — | — |
| REQ-F-054 | Representative ward dashboard: open issues by category and age, overdue list, hotspots map, resolution tren... | TASK-11 | Not Verified | — | — |
| REQ-F-055 | Representatives can acknowledge, comment and mark fixed on issues in their wards only | TASK-11 | Not Verified | — | — |
| REQ-F-056 | Representative inbox for relayed messages with reply-by-email tracking | TASK-11 | Not Verified | — | — |
| REQ-F-057 | AMC services directory: categories, service pages (gu/en) with online/offline flag, official link, how-to s... | TASK-12 | Not Verified | — | — |
| REQ-F-058 | Monthly link check marks broken service links for staff review | TASK-12 | Not Verified | — | — |
| REQ-F-059 | Initiatives (tree drives, clean-ups, health camps) list and detail with organiser and source | TASK-12 | Not Verified | — | — |
| REQ-F-060 | RSVP to initiatives with reminder 24 h before; staff can mark attendance | TASK-12 | Not Verified | — | — |
| REQ-F-061 | Seasonal service tips on Home (property-tax rebate window, monsoon, heat) managed by staff | TASK-12 | Not Verified | — | — |
| REQ-D-001 | PostGIS enabled: compose image `postgis/postgis:17-3.5`, `CREATE EXTENSION postgis` in a new migration, loc... | TASK-01 | Not Verified | — | — |
| REQ-D-002 | New v2 tables per spec §6 created only through new migrations; applied v1 migrations untouched | TASK-01 | Not Verified | — | — |
| REQ-D-003 | `users`, `consents`, `devices` tables with constraints (unique phone, unique firebase uid, role enum) | TASK-01 | Not Verified | — | — |
| REQ-D-004 | `issues`, `issue_photos`, `issue_events`, `issue_verifications`, `me_toos`, `follows` with geography point,... | TASK-01 | Not Verified | — | — |
| REQ-D-005 | Legacy migration: every v1 complaint copied into `issues` with mapped status and `legacy_complaint_id`; v1 ... | TASK-01 | Not Verified | — | — |
| REQ-D-006 | `zones` and `wards` seeded from the OpenCity KML (48 wards, 7 zones) with boundary version, cross-checked a... | TASK-02 | Not Verified | — | — |
| REQ-D-007 | `categories` seeded with the 14 v2 categories and `amc_problem_types` mapping | TASK-05 | Not Verified | — | — |
| REQ-D-008 | `representatives`, `representative_areas`, `assembly_constituencies`, `ward_constituency`, `rep_claims`, `r... | TASK-09 | Not Verified | — | — |
| REQ-D-009 | `alerts`, `alert_wards`, `subscriptions`, `notifications` tables with status and validity constraints | TASK-08 | Not Verified | — | — |
| REQ-D-010 | `services`, `initiatives`, `rsvps` tables | TASK-12 | Not Verified | — | — |
| REQ-D-011 | `moderation_flags` and `app_settings` (election mode, flags) tables | TASK-10 | Not Verified | — | — |
| REQ-D-012 | Ward scorecard computed by a SQL view or materialised view refreshed hourly | TASK-09 | Not Verified | — | — |
| REQ-D-013 | Development seed for v2: wards, categories, sample citizens, issues in every status, representatives (ficti... | TASK-01 | Not Verified | — | — |
| REQ-N-001 | Design tokens per DS §2 replace v1 tokens; no colour literal outside the theme; semantic token names | TASK-03 | Not Verified | — | — |
| REQ-N-002 | Typography per DS §3 with bundled Gujarati + Latin fonts (subset), Indic line heights, scale to 200% withou... | TASK-03 | Not Verified | — | — |
| REQ-N-003 | Component library per DS §5 (app bar, bottom nav, buttons, inputs, chips, list rows, cards, status timeline... | TASK-03 | Not Verified | — | — |
| REQ-N-004 | Accessibility: 48 dp targets, labels on all controls, contrast AA, icon + text for every status, TalkBack o... | TASK-03 | Not Verified | — | — |
| REQ-N-005 | Complete Gujarati and English ARB translations for every string; no hard-coded strings | TASK-03 | Not Verified | — | — |
| REQ-N-006 | Dark theme from the same tokens | TASK-03 | Not Verified | — | — |
| REQ-N-007 | Report sheet completes in ≤ 4 taps after the photo for a typical issue; cold start ≤ 3 s on a low-end phone... | TASK-05 | Not Verified | — | — |
| REQ-N-008 | Map renders 2,000 issues smoothly using server clustering and client clustering | TASK-07 | Not Verified | — | — |
| REQ-N-009 | Automated tests: API integration tests (Vitest + Supertest) for auth, issue lifecycle, permissions and rate... | TASK-01 | Not Verified | — | — |
| REQ-N-010 | Flutter widget tests for core components and an integration test of report → verify on the emulator | TASK-14 | Not Verified | — | — |
| REQ-N-011 | All list endpoints paginated; p95 latency < 400 ms for feed, list and detail on pilot data | TASK-07 | Not Verified | — | — |
| REQ-S-001 | Firebase ID tokens verified server-side (signature, audience, issuer, expiry); session JWT with token version | TASK-04 | Not Verified | — | — |
| REQ-S-002 | Role-based authorisation on every staff endpoint; representatives scoped to their wards | TASK-10 | Not Verified | — | — |
| REQ-S-003 | Purpose-specific consent records (core, share with representatives, AMC hand-off, notifications) with withd... | TASK-04 | Not Verified | — | — |
| REQ-S-004 | Data export (`GET /me/export`) and account deletion (`DELETE /me`) that anonymises issues and deletes the p... | TASK-04 | Not Verified | — | — |
| REQ-S-005 | Under-18 users blocked with an age confirmation at sign-in | TASK-04 | Not Verified | — | — |
| REQ-S-006 | Public views never expose reporter phone or name; "A resident of <ward>" | TASK-07 | Not Verified | — | — |
| REQ-S-007 | Faces and number plates blurred on-device before upload, with manual blur fallback | TASK-05 | Not Verified | — | — |
| REQ-S-008 | Per-user rate limits per spec §7 (issues, me-too, messages, verifications) | TASK-05 | Not Verified | — | — |
| REQ-S-009 | Message relay rate-limited (5/day per representative), profanity screen, citizen phone hidden by default | TASK-09 | Not Verified | — | — |
| REQ-S-010 | Every staff action logged in the audit log with actor, role and target; no bodies or PII | TASK-10 | Not Verified | — | — |
| REQ-S-011 | Alerts always show source and validity; no AMC logo; "independent app" label on About, alerts, services and... | TASK-08 | Not Verified | — | — |
| REQ-S-012 | Representative data shows only office or consented contacts; personal numbers never imported | TASK-09 | Not Verified | — | — |
| REQ-S-013 | HTTPS everywhere outside local; cleartext exceptions only in debug builds (profile exception removed) | TASK-13 | Not Verified | — | — |
| REQ-S-014 | Retention jobs: photos of closed issues after 2 years, logs 14 days, notifications 90 days | TASK-13 | Not Verified | — | — |
| REQ-S-015 | v1 logging redaction extended to OTP, Firebase tokens, FCM tokens and message bodies | TASK-04 | Not Verified | — | — |
| REQ-O-001 | Prisma schema updated for v2 with PostGIS columns via `Unsupported` or raw SQL; `prisma generate`, typechec... | TASK-01 | Not Verified | — | — |
| REQ-O-002 | `npm run demo:reset` and `db:reset` work with v2 seed | TASK-01 | Not Verified | — | — |
| REQ-O-003 | Firebase project configuration documented (Android app, SHA fingerprints, service account for the API) with... | TASK-04 | Not Verified | — | — |
| REQ-O-004 | Cloudflare R2 storage driver implemented behind the storage interface and selectable by `STORAGE_DRIVER` | TASK-13 | Not Verified | — | — |
| REQ-O-005 | Staging and pilot environments: API behind HTTPS, managed PostgreSQL with PostGIS, environment variables do... | TASK-13 | Not Verified | — | — |
| REQ-O-006 | Daily database backup, R2 versioning, and a restore drill recorded before launch | TASK-13 | Not Verified | — | — |
| REQ-O-007 | Uptime monitoring on `/health` and error alerting without PII | TASK-13 | Not Verified | — | — |
| REQ-O-008 | Android release signing, Play internal and closed testing tracks, Data safety form matching §11 | TASK-13 | Not Verified | — | — |
| REQ-O-009 | Full v2 end-to-end verification on emulator and a physical low-end Android phone; coverage matrix closed | TASK-14 | Not Verified | — | — |
| REQ-O-010 | Accessibility audit (TalkBack, largest font, Gujarati) of report, issue detail, alerts and My Ward | TASK-14 | Not Verified | — | — |
| REQ-O-011 | Pilot launch checklist: 5 West-zone wards seeded with verified representatives, services and moderators onb... | TASK-14 | Not Verified | — | — |
| REQ-O-012 | v1 spec documents marked superseded where v2 differs; summary links to v2 spec | TASK-14 | Not Verified | — | — |
